# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Warning: loading this currently takes between 15 and 50 minutes, depending on the
# environment (15 for a local box, 50 for an ec2 instance).

require "countries"
require "csv"


def create_geocode(address, lat, lng)
  begin
    Geocode.create!(:address => address, :latitude => lat, :longitude => lng)
  rescue ActiveRecord::RecordNotUnique
  
    # Fine to ignore duplicate key errors, since these might have already
    # been added.
  end
end


# Loads geocodes based on the locations of the authors in the most recently
# published PLOS articles.  This is about 4500 geocodes.
def load_from_csv(filename)
  CSV.foreach(filename) do |row|
    create_geocode(row[0], row[1].to_f, row[2].to_f)
  end
end


# There are a few cases where names as returned by the countries module are
# different from the names used in the affiliates field.  We take care of
# them here.
COUNTRY_NAME_REPLACEMENTS = {
    :"United States" => "United States of America"
    }

def get_country_name(country_code)
  if country_code.nil?
    return nil
  else
    country = Country.new(country_code)
    if country.data.nil?
      return nil
    else
      if !COUNTRY_NAME_REPLACEMENTS[country.name.to_sym].nil?
        return COUNTRY_NAME_REPLACEMENTS[country.name.to_sym]
      else
        return country.name
      end
    end
  end
end


US_STATES = {
    :AL => "Alabama",
    :AK => "Alaska",
    :AZ => "Arizona",
    :AR => "Arkansas",
    :CA => "California",
    :CO => "Colorado",
    :CT => "Connecticut",
    :DE => "Delaware",
    :FL => "Florida",
    :GA => "Georgia",
    :HI => "Hawaii",
    :ID => "Idaho",
    :IL => "Illinois",
    :IN => "Indiana",
    :IA => "Iowa",
    :KS => "Kansas",
    :KY => "Kentucky",
    :LA => "Louisiana",
    :ME => "Maine",
    :MD => "Maryland",
    :MA => "Massachusetts",
    :MI => "Michigan",
    :MN => "Minnesota",
    :MS => "Mississippi",
    :MO => "Missouri",
    :MT => "Montana",
    :NE => "Nebraska",
    :NV => "Nevada",
    :NH => "New Hampshire",
    :NJ => "New Jersey",
    :NM => "New Mexico",
    :NY => "New York",
    :NC => "North Carolina",
    :ND => "North Dakota",
    :OH => "Ohio",
    :OK => "Oklahoma",
    :OR => "Oregon",
    :PA => "Pennsylvania",
    :RI => "Rhode Island",
    :SC => "South Carolina",
    :SD => "South Dakota",
    :TN => "Tennessee",
    :TX => "Texas",
    :UT => "Utah",
    :VT => "Vermont",
    :VA => "Virginia",
    :WA => "Washington",
    :WV => "West Virginia",
    :WI => "Wisconsin",
    :WY => "Wyoming",
    }
    
CANADA_PROVINCES = {
    :ON => "Ontario",
    :QC => "Quebec",
    :NS => "Nova Scotia",
    :NB => "New Brunswick",
    :MB => "Manitoba",
    :BC => "British Columbia",
    :PE => "Prince Edward Island",
    :SK => "Saskatchewan",
    :AB => "Alberta",
    :NL => "Newfoundland and Labrador",
    }

def get_region(country, region)
  if country == "US"
    US_STATES[region.to_sym]
  elsif country == "CA"
    CANADA_PROVINCES[region.to_sym]
  else
    nil
  end
end


# Loads geocodes from a file downloaded from http://www.maxmind.com/en/opensource .
# This is mostly a package intended for IP-geolocation, but it also includes
# lat/lng for all cities.  This is about 317k geocodes.
def load_from_geolite
  
  # Note: I had to convert the GeoLite file from ISO-8859 to UTF-8 before this script
  # could work.  Like this:
  #   iconv -f ISO-8859-1 -t utf-8 GeoLiteCity-Location.csv > GeoLiteCity-Location_utf8.csv
  CSV.foreach("db/GeoLiteCity-Location_utf8.csv") do |row|
    country = get_country_name(row[1])
    region = get_region(row[1], row[2])
    city = row[3]
    lat = row[5]
    lng = row[6]
    if country.to_s != "" && city.to_s != "" && lat.to_f != 0.0 && lng.to_f != 0.0
      if region.to_s == ""
        address = "#{city}, #{country}"
      else
        address = "#{city}, #{region}, #{country}"
      end
      create_geocode(address, lat.to_f, lng.to_f)
    end
  end
end


puts "Loading countries..."
load_from_csv("db/countries.csv")
puts "Loading geocode data from article subset (4k)..."
load_from_csv("db/geocodes.csv")
puts "Loading geocode data from geolite (300k)..."
load_from_geolite
