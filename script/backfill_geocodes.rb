# Script that backfills the geocodes table based on the most popular
# locations for all articles in the PLOS corpus.  DOIs for the corpus
# are retrieved from an ambra DB.
#
# Usage: rails runner script/backfill_geocodes.rb

require "mysql2"

# Number of DOIs we send to solr per request.
BATCH_SIZE = 100

# This is the maximum number of DOIs we examine per run of the script.
# This should be a multiple of BATCH_SIZE.
SOLR_ARTICLES_TO_QUERY = 1000

DB_HOST = "localhost"

DB_USER = "root"

DB_PASSWD = ""

DB_NAME = "ambra"


# Returns the SOLR_ARTICLES_TO_QUERY most recent, published articles in the
# corpus.
def get_dois
  client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password => DB_PASSWD,
      :database => DB_NAME)
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
      yield batch
    end
  end until last_article_id == 0 || batch.length == 0 || total_articles >= SOLR_ARTICLES_TO_QUERY
end


# TODO: move somewhere else and also call from ReportsController

# Contains countries where we have affiliate data of the form "City, Province, Country".
# For all other countries the affiliate is in the form "Province, Country".
COUNTRIES_WITH_CITIES = Set.new([
    "United States of America",
    "Australia",
    ])

def parse_location_from_affiliate(affiliate)
  fields = affiliate.split(",")
  fields.map { |location| location.strip! }
  if fields.length >= 3
    if COUNTRIES_WITH_CITIES.include?(fields[-1])
      fields[-3, 3].join(", ")
    else
      fields[-2, 2].join(", ")
    end
  else
    nil
  end
end


locations_to_count = Hash.new{|h, k| h[k] = 0}
get_dois do |dois|
  solr = SolrRequest.get_data_for_articles(dois)
  dois.each do |doi|
    if !solr[doi].nil? && !solr[doi]["affiliate"].nil? && solr[doi]["affiliate"].length > 0
      solr[doi]["affiliate"].each do |affiliate|
        location = parse_location_from_affiliate(affiliate)
        if !location.nil?
          locations_to_count[location] += 1
        end
      end
    end
  end
end
sorted = locations_to_count.sort_by {|_, value| -value}
sorted.each do |location, _|
  # TODO: geocode location and store in geocodes table
end
