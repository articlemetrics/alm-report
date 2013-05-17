
# Warning: this migration will delete all existing rows from the geocodes table!
class PopulateGeocodes < ActiveRecord::Migration
  
  def up
    sqls = File.read("db/migrate/populate_geocodes.sql").split("\n")
    Geocode.delete_all
    sqls.each {|sql| execute sql}
  end
  
  
  def down
    Geocode.delete_all
  end

end
