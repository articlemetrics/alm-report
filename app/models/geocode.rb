require "set"

# Stores the latitude and longitude for a given address in the DB.
class Geocode < ActiveRecord::Base
  attr_accessible :address, :latitude, :longitude
  
  
  # Map of variations of certain countries' names, to the value that we
  # have stored in the geocodes table.
  @@COUNTRY_SYNONYMS = {
      :brasil => "brazil",
      :"people's republic of china" => "china",
      :"peoples' republic of china" => "china",
      :"pr china" => "china",
      :"republic of panama" => "panama",
      :"the netherlands" => "netherlands",
      }
  
  
  # Performs a batch query against the addresses field of the geocodes table and
  # returns results as a map of address to geocode object.
  def self.load_from_addresses_impl(addresses)
    geos = Geocode.where(:address => addresses)
    results = {}
    geos.each {|geo| results[geo.address] = geo}
    results
  end
  
  
  # Returns an array of addresses that are in the input addresses array, and are
  # not present as a key of the geocodes map (with case-insensitive matching).
  def self.find_difference(addresses, geocodes)
    lower_addrs = Set.new(addresses.map {|a| a.downcase})
    lower_geos = Set.new(geocodes.keys.map {|a| a.downcase})
    diff = lower_addrs - lower_geos
    diff.to_a
  end
  
  
  # Attempts to load geocodes for all of the given addresses.  Batch queries
  # are used for efficiency.  Several queries may be issued, from most specific
  # (the entire address) to least specific (just the country), depending on
  # whether we find the address at the previous stage.  Returns a map
  # from input address to geocode object (not all input addresses may be present
  # in the output, if they were not found).
  def self.load_from_addresses(addrs)
    addresses = addrs.map {|a| a.downcase}

    # 1. Use the entire address
    geocodes = load_from_addresses_impl(addresses)
    if geocodes.length < addresses.length
      not_found = find_difference(addresses, geocodes)
      
      # 2. Substitute country synonyms we know we have in the DB.
      country_synonym_addrs = []
      not_found.each do |address|
        fields = address.split(",")
        country = fields[-1].strip.downcase
        if !@@COUNTRY_SYNONYMS[country.to_sym].nil?
          country = @@COUNTRY_SYNONYMS[country.to_sym]
          country_synonym_addrs << "#{fields[-2].strip()}, #{country}"
        end
      end
      if country_synonym_addrs.length > 0
        geocodes.merge!(load_from_addresses_impl(Set.new(country_synonym_addrs).to_a))
      end
      if geocodes.length < addresses.length
        not_found = find_difference(addresses, geocodes)
        
        # 3. Sometimes, addresses for countries where we normally get
        # "City, Province, Country" only have "City, Country".
        city_country_addrs = []
        not_found.each do |address|
          fields = address.split(",")
          if fields.length == 3
            country = fields[-1].strip.downcase
            country = @@COUNTRY_SYNONYMS[country.to_sym].nil? ? country : @@COUNTRY_SYNONYMS[country.to_sym]
            city_country_addrs << "#{fields[1].strip()}, #{country}"
          end
        end
        if city_country_addrs.length > 0
          geocodes.merge!(load_from_addresses_impl(Set.new(city_country_addrs).to_a))
        end
      end
      if geocodes.length < addresses.length
        not_found = find_difference(addresses, geocodes)
        
        # 4. If all else fails, just attempt to geocode the country.
        country_addrs = []
        not_found.each do |address|
          fields = address.split(",")
          country = fields[-1].strip.downcase
          country = @@COUNTRY_SYNONYMS[country.to_sym].nil? ? country : @@COUNTRY_SYNONYMS[country.to_sym]
          country_addrs << country
        end
        geocodes.merge!(load_from_addresses_impl(Set.new(country_addrs).to_a))
      end
    end
    geocodes
  end
  
end
