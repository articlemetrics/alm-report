require "date"
require "net/http"
require "open-uri"
require "json"

# Interface to solr search for PLOS articles.  A thin wrapper around the solr http API.
#
# TODO: move this somewhere more appropriate.  (lib?  app/lib?)
# I tried doing this but rails could not load the file for some reason.
class SolrRequest
  
  # Base URL of solr server.
  URL = "http://api.plos.org/search"
  
  RESULTS_PER_PAGE = 25
  
  DEBUG = true

  # Creates a solr request.  The query (q param in the solr request) will be based on
  # the values of the params passed in, so these should all be valid entries in the PLOS schema.
  def initialize(params)
    @params = params
  end
  
  # Returns the portion of the solr URL with the q parameter, specifying the search.
  def build_query
 
    # Strip out empty params.  Has to be done in a separate loop from the one below to
    # preserve the AND logic.
    solr_params = {}
    @params.keys.each do |key|
      value = @params[key].strip
      if value.length > 0
        solr_params[key] = value
      end
    end
    
    query = "q="
    keys = solr_params.keys
    keys.each_with_index do |key, i|
      encoded = URI::encode(solr_params[key])
      if encoded != solr_params[key]
        encoded = "\"#{encoded}\""
      end
      query << "#{key}:#{encoded}"
      if keys.length > 1 && i < keys.length - 1
        query << "%20AND%20"
      end
    end

    # TODO: author_country, institution.  Use author affiliations.
    # TODO: publication_date: needs additional formatting

    return query
  end
                
  # Performs a single solr search, based on the parameters set on this object.  Returns a tuple
  # of the documents retrieved, and the total number of results.  TODO: results paging.
  def query
    
    # TODO: set additional search attributes.
    query = build_query
    filter = "fq=doc_type:full&fq=article_type_facet:#{CGI.escape("\"Research Article\"")}"
    fl = "fl=id,publication_date,title,journal,author_display"
    limit = "rows=#{RESULTS_PER_PAGE}"  # TODO: result paging
    url = "#{URL}?#{query}&#{filter}&#{fl}&wt=json&#{limit}"
    if DEBUG
      puts "solr query: #{url}"
    end
    resp = Net::HTTP.get_response(URI.parse(url))
    if resp.code != "200"
      raise "Server returned #{resp.code}: " + resp.body
    end
    json = JSON.parse(resp.body)
#    if DEBUG
#      puts json["response"]["docs"]
#    end
    docs = json["response"]["docs"]
    docs.each do |doc|
      doc["publication_date"] = Date.strptime(doc["publication_date"], "%Y-%m-%dT%H:%M:%SZ")
    end
    return docs, json["response"]["numFound"]
  end
                
end
