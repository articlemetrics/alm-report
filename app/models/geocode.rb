# Stores the latitude and longitude for a given address in the DB.
class Geocode < ActiveRecord::Base
  attr_accessible :address, :latitude, :longitude
end
