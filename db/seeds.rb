# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require "csv"

CSV.foreach("db/more_geocodes.csv") do |row|
  begin
    Geocode.create!(:address => row[0], :latitude => row[1].to_f, :longitude => row[2].to_f)
  rescue ActiveRecord::RecordNotUnique
    
    # Fine to ignore duplicate key errors, since these might have already
    # been added.
  end
end
