require "date"
require "net/http"
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
  
  attr_accessor :keyword,
                :author,
                :author_country,
                :institution,
                :publication_date,
                :subject,
                :journal,
                :funder
                
  # Performs a single solr search, based on the parameters set on this object.  Returns a tuple
  # of the documents retrieved, and the total number of results.  TODO: results paging.
  def query
    
    # TODO: set additional search attributes.
    query = "q=everything:#{@keyword}"
    filter = "fq=doc_type:full&fq=article_type_facet:#{CGI.escape("\"Research Article\"")}"
    fl = "fl=id,publication_date,title,journal,author"
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
