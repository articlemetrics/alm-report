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
  
  # Adds leading and trailing double-quotes to the string if it contains any whitespace.
  def quote_if_spaces(s)
    if /\s/.match(s)
      s = "\"#{s}\""
    end
    return s
  end
  
  # The search page uses two form fields, author_country and institution, that are both
  # implemented by mapping onto the same field in the solr schema: affiliate.  This method
  # handles building the affiliate param based on the other two (whether or not they are
  # present).  It will also delete the two "virtual" params as a side-effect.
  def build_affiliate_param(solr_params)
    part1 = solr_params.delete(:author_country).to_s.strip
    part2 = solr_params.delete(:institution).to_s.strip
    if part1.length == 0 && part2.length == 0
      return solr_params
    end
    both = part1.length > 0 && part2.length > 0
    solr_params[:affiliate] = (both ? "(" : "") + quote_if_spaces(part1) + (both ? " AND " : "") \
        + quote_if_spaces(part2) + (both ? ")" : "")
=begin
    if part1.length > 0
      value << quote_if_spaces(part1)
    end
    if both
      value << " AND "
    end
    if part2.length > 0
      value << quote_if_spaces(part2)
    end
    if both
      value << ")"
    end
=end
    return solr_params
  end
  
  # Returns the portion of the solr URL with the q parameter, specifying the search.
  # Note that the results of this method *must* be URL-escaped before use.
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
    
    solr_params = build_affiliate_param(solr_params)
    query = "q="
    
    # Sort the keys to ensure deterministic param order.  This is mainly for testing.
    keys = solr_params.keys.sort
    keys.each_with_index do |key, i|
      value = solr_params[key]
      if key != :affiliate  # :affiliate was already quoted in build_affiliate_param
        value = quote_if_spaces(value)
      end
      query << "#{key}:#{value}"
      if keys.length > 1 && i < keys.length - 1
        query << " AND "
      end
    end

    # TODO: author_country, institution.  Use author affiliations.
    # TODO: publication_date: needs additional formatting

    if DEBUG
      puts "solr query: #{query}"
    end
    return query
  end
                
  # Performs a single solr search, based on the parameters set on this object.  Returns a tuple
  # of the documents retrieved, and the total number of results.  TODO: results paging.
  def query
    
    # TODO: set additional search attributes.
    filter = "fq=doc_type:full&fq=article_type_facet:#{CGI.escape("\"Research Article\"")}"
    fl = "fl=id,publication_date,title,journal,author_display"
    limit = "rows=#{RESULTS_PER_PAGE}"  # TODO: result paging
    url = "#{URL}?#{URI::encode(build_query)}&#{filter}&#{fl}&wt=json&#{limit}"
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
