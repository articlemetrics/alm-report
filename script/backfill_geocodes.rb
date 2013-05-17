# Script that backfills the geocodes table based on the most popular locations
# for a set of PLOS articles.  Article can either be supplied as a text file
# (one DOI per line), or they will be retrieved from an ambra database.
#
# Usage: rails runner script/backfill_geocodes.rb <doi_file>
#   if <doi_file> is absent, DOIs will instead be retrieved from the ambra DB.

require "mysql2"

# Number of DOIs we send to solr per request.
BATCH_SIZE = 100

# This is the maximum number of DOIs we examine per run of the script.
# This should be a multiple of BATCH_SIZE.
SOLR_ARTICLES_TO_QUERY = 5000

DB_HOST = "***REMOVED***"

DB_PORT = 3307

DB_USER = "ambra"

DB_PASSWD = ""

DB_NAME = "ambra"


# Yields batches of DOIs, from the given file if it is defined, or else from the database.
def get_dois(doi_file, &block)
  if doi_file.nil?
    puts "Retrieving DOIs from ambra DB..."
    get_dois_from_db(&block)
  else
    puts "Using #{doi_file}..."
    get_dois_from_file(doi_file, &block)
  end
end


# Yields batchs of DOIs from a file.
def get_dois_from_file(doi_file, &block)
  dois = File.read(doi_file).split("\n").map{|doi| doi[9..doi.length]}  # Remove "info:doi/"
  start = 0
  while start < dois.length && start < SOLR_ARTICLES_TO_QUERY
    block.call(dois[start, BATCH_SIZE])
    start += BATCH_SIZE
  end
end


# Yields batches of DOIs from the ambra database.  They are returned in descending
# order of publication date.
def get_dois_from_db(&block)
  client = Mysql2::Client.new(:host => DB_HOST, :port => DB_PORT, :username => DB_USER,
      :password => DB_PASSWD, :database => DB_NAME)
  last_article_id = 1000000000
  total_articles = 0
  begin
    sql = "SELECT doi, articleID FROM article
        WHERE (state = 0) AND (doi like 'info:doi/10.1371/journal.p%') AND articleID < #{last_article_id}
        ORDER BY articleID DESC LIMIT #{BATCH_SIZE};"
    rs = client.query(sql)
    batch = []
    rs.each do |row|
      batch << row["doi"][9..row["doi"].length]  # Remove "info:doi/"
      last_article_id = row["articleID"]
      total_articles += 1
    end
    if batch.length > 0
      block.call(batch)
    end
  end until last_article_id == 0 || batch.length == 0 || total_articles >= SOLR_ARTICLES_TO_QUERY
end


locations_to_count = Hash.new{|h, k| h[k] = 0}
get_dois(ARGV[0]) do |dois|
  solr = SolrRequest.get_data_for_articles(dois)
  dois.each do |doi|
    if !solr[doi].nil? && !solr[doi]["affiliate"].nil? && solr[doi]["affiliate"].length > 0
      solr[doi]["affiliate"].each do |affiliate|
        location = GeocodeRequest.parse_location_from_affiliate(affiliate)
        if !location.nil?
          locations_to_count[location] += 1
        end
      end
    end
  end
end

sorted = locations_to_count.sort_by {|_, value| -value}
sorted.each do |location, _|
  existing = Geocode.where("address = ?", location)
  if existing.length >= 1
    puts "#{location} already found in DB, skipping."
  else
    begin
      latlng = GeocodeRequest.geocode(location)
      puts "#{location} successfully geocoded to #{latlng[0]}, #{latlng[1]}"
      Geocode.create(:address => location, :latitude => latlng[0], :longitude => latlng[1])
    rescue GeocodeError => ge
      puts "Error geocoding #{location}: #{ge.message}; SKIPPING"
    end
  end
end
