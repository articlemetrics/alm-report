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
    if country && country.data
      if !COUNTRY_NAME_REPLACEMENTS[country.name.to_sym].nil?
        return COUNTRY_NAME_REPLACEMENTS[country.name.to_sym]
      else
        return country.name
      end
    else
      return nil
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

  # Skip first line of CSV, which contains the copyright
  locations = File.read('db/seed/GeoLiteCity-Location.csv',
    encoding: 'iso-8859-1'
  ).lines[1..-1].join

  CSV.parse(locations, headers: true) do |row|
    country = get_country_name(row['country'])
    region = get_region(row['country'], row['region'])
    city = row['city']
    lat = row['latitude']
    lng = row['longitude']
    if country && city && lat.to_f != 0.0 && lng.to_f != 0.0
      if region
        address = "#{city}, #{country}"
      else
        address = "#{city}, #{region}, #{country}"
      end
      create_geocode(address, lat.to_f, lng.to_f)
    end
  end
end

puts "Loading countries..."
load_from_csv("db/seed/countries.csv")
puts "Loading geocode data from article subset (4k)..."
load_from_csv("db/seed/geocodes.csv")
puts "Loading geocode data from geolite (300k)..."
# TODO: Travis failing because this takes too long.
# load_from_geolite
