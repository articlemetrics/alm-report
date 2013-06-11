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
  
  
  # Performs a batch query against the addresses field of the geocodes table.
  #
  # Input: a map where the keys are the addresses that will be queried, and
  #     the values are "original" addresses which are associated with the keys.
  #
  # Output: a tuple of a map from address to geocode object, and a list of the
  #     original addresses that were found.
  def self.load_from_addresses_impl(addresses)
    geos = Geocode.where(:address => addresses.keys)
    results = {}
    orig_addresses = []
    geos.each do |geo|
      results[geo.address] = geo
      orig_addresses << addresses[geo.address.downcase]
    end
    [results, orig_addresses]
  end
  
  
  # Attempts to load geocodes for all of the given addresses.  Batch queries
  # are used for efficiency.  Several queries may be issued, from most specific
  # (the entire address) to least specific (just the country), depending on
  # whether we find the address at the previous stage.  Returns a map
  # from input address to geocode object (not all input addresses may be present
  # in the output, if they were not found).
  def self.load_from_addresses(addrs)
    
    # Copy the addresses into a set.  We will delete them from this set as
    # they are found in the DB.
    addresses = Set.new(addrs.map{|a| a.downcase})

    # 1. Use the entire address
    address_map = {}
    addresses.each {|a| address_map[a] = a}
    geocodes, orig_addresses = load_from_addresses_impl(address_map)
    orig_addresses.each {|i| addresses.delete(i)}
    if addresses.length > 0

      # 2. Substitute country synonyms we know we have in the DB.
      substitutions = {}
      addresses.each do |address|
        fields = address.split(",")
        country = fields[-1].strip.downcase
        if !@@COUNTRY_SYNONYMS[country.to_sym].nil?
          country = @@COUNTRY_SYNONYMS[country.to_sym]
          substitutions["#{fields[-2].strip()}, #{country}"] = address
        end
      end
      if substitutions.length > 0
        found, orig_addresses = load_from_addresses_impl(substitutions)
        geocodes.merge!(found)
        orig_addresses.each {|i| addresses.delete(i)}
      end
      if addresses.length > 0

        # 3. Sometimes, addresses for countries where we normally get
        # "City, Province, Country" only have "City, Country".
        substitutions = {}
        addresses.each do |address|
          fields = address.split(",")
          if fields.length == 3
            country = fields[-1].strip.downcase
            country = @@COUNTRY_SYNONYMS[country.to_sym].nil? ? country : @@COUNTRY_SYNONYMS[country.to_sym]
            substitutions["#{fields[1].strip()}, #{country}"] = address
          end
        end
        if substitutions.length > 0
          found, orig_addresses = load_from_addresses_impl(substitutions)
          geocodes.merge!(found)
          orig_addresses.each {|i| addresses.delete(i)}
        end
      end
      if addresses.length > 0

        # 4. If all else fails, just attempt to geocode the country.
        substitutions = {}
        addresses.each do |address|
          fields = address.split(",")
          country = fields[-1].strip.downcase
          country = @@COUNTRY_SYNONYMS[country.to_sym].nil? ? country : @@COUNTRY_SYNONYMS[country.to_sym]
          substitutions[country] = address
        end
        if substitutions.length > 0
          found, orig_addresses = load_from_addresses_impl(substitutions)
          geocodes.merge!(found)
          orig_addresses.each {|i| addresses.delete(i)}
        end
      end
    end
    [geocodes, addresses.to_a]
  end
  
end
