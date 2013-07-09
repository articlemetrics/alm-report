require "date"
require "net/http"
require "open-uri"
require "json"

# Exception class thrown when the solr server returns a 50x response.
class SolrError < StandardError
end


# Interface to solr search for PLOS articles.  A thin wrapper around the solr http API.
#
# TODO: consider renaming this class.  Originally I thought there would also be a SolrResponse,
# but that was not necessary.
class SolrRequest
  
  @@SOLR_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
  
  @@FILTER = "fq=doc_type:full&fq=!article_type_facet:#{URI::encode("\"Issue Image\"")}"
  
  # The fields we want solr to return for each article by default.
  @@FL = "id,publication_date,title,cross_published_journal_name,author_display,article_type," \
      "affiliate,subject,pmid"

  @@FL_METRIC_DATA = "id,alm_scopusCiteCount,alm_mendeleyCount,counter_total_all," \
      "alm_pmc_usage_total_all"

  @@FL_VALIDATE_ID = "id"

  @@ALL_JOURNALS = "All Journals"


  # Creates a solr request.  The query (q param in the solr request) will be based on
  # the values of the params passed in, so these should all be valid entries in the PLOS schema.
  # If the fl argument is non-nil, it will specify what result fields to return from
  # solr; otherwise all fields that we are interested in will be returned.
  def initialize(params, fl=nil)
    @params = params
    if fl.nil?
      @fl = "fl=#{@@FL}"
    else
      @fl = "fl=#{fl}"
    end
  end


  def self.ALL_JOURNALS
    return @@ALL_JOURNALS
  end


  # Adds leading and trailing double-quotes to the string if it contains any whitespace.
  def quote_if_spaces(s)
    if /\s/.match(s)
      s = "\"#{s}\""
    end
    return s
  end
  private :quote_if_spaces


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
    return solr_params
  end
  private :build_affiliate_param


  # Returns the portion of the solr URL with the q parameter, specifying the search.
  # Note that the results of this method *must* be URL-escaped before use.
  def build_query

    # Strip out empty params.  Has to be done in a separate loop from the one below to
    # preserve the AND logic.
    solr_params = {}
    @params.keys.each do |key|
      value = @params[key].strip
      
      # Also take this opportunity to strip out the bogus "all journals" journal value.
      # It is implicit.
      if value.length > 0 && (key.to_s != "cross_published_journal_name" || value != @@ALL_JOURNALS)
        solr_params[key] = value
      end
    end
    
    solr_params = build_affiliate_param(solr_params)
    query = "q="
    
    # Sort the keys to ensure deterministic param order.  This is mainly for testing.
    keys = solr_params.keys.sort
    keys.each_with_index do |key, i|
      value = solr_params[key]
      if key != :affiliate && key != :publication_date  # params assumed to be pre-formatted
        value = quote_if_spaces(value)
      end
      query << "#{key}:#{value}"
      if keys.length > 1 && i < keys.length - 1
        query << " AND "
      end
    end

    # if the user hasn't entered in anything, search for everything
    if keys.empty?
      query << "*:*"
    end

    Rails.logger.debug("solr query: #{query}")
    return query
  end


  # Returns the portion of the solr URL with the query parameter and journal filter populated
  def build_advanced_query
    solr_params = {}

    if @params.has_key?(:unformattedQueryId)
      solr_params[:q] = @params[:unformattedQueryId].strip
    else
      # this shouldn't happen but just in case
      solr_params[:q] = "*:*"
    end

    if @params.has_key?(:filterJournals)
      filter_journals = @params[:filterJournals]
      solr_params[:fq] = filter_journals.map { | filter_journal | "cross_published_journal_key:#{filter_journal}" }.join(" OR ")
    end

    return solr_params
  end


  def self.send_query(url)
    start_time = Time.now
    resp = Net::HTTP.get_response(URI.parse(url))
    end_time = Time.now
    Rails.logger.debug "SOLR Request took #{end_time - start_time} seconds\n#{url}"

    if resp.code != "200"
      raise SolrError, "Server returned #{resp.code}: " + resp.body
    end
    return JSON.parse(resp.body)
  end
  
  
  # Returns a list of JSON entities for article results given a json response from solr.
  def self.parse_docs(json)
    docs = json["response"]["docs"]
    docs.each do |doc|
      doc = fix_data(doc)
    end
    return docs
  end
  
  
  # Returns the fragment of the URL having to do with paging; specifically, the rows
  # and start parameters.  These can be passed in directly to the constructor, or calculated
  # based on the current_page param, if it is present.
  def build_page_block
    rows = @params.delete(:rows)
    page_size = rows.nil? ? APP_CONFIG["results_per_page"] : rows
    result = "rows=#{page_size}"
    start = @params.delete(:start)
    if start.nil?
      page = @params.delete(:current_page)
      page = page.nil? ? "1" : page
      page = page.to_i - 1
      if page > 0
        result << "&start=#{page * APP_CONFIG["results_per_page"] + 1}"
      end
    else  # start is specified
      result << "&start=#{start}"
    end
    result
  end


  # Performs a single solr search, based on the parameters set on this object.  Returns a tuple
  # of the documents retrieved, and the total number of results.
  def query
    sort = @params.delete(:sort)
    page_block = build_page_block  # This needs to get called before build_query

    common_params = "#{@@FILTER}&#{@fl}&wt=json&facet=false&#{page_block}"

    if !@params.has_key?(:unformattedQueryId)
      # execute home page search
      url = "#{APP_CONFIG["solr_url"]}?#{URI::encode(build_query)}&#{common_params}"
    else
      # advanced search query
      solr_params = build_advanced_query
      url = "#{APP_CONFIG["solr_url"]}?#{solr_params.to_param}&#{common_params}"
    end

    if !sort.nil?
      url << "&sort=#{URI::encode(sort)}"
    end
    # exclude things that we do not need (hl => highlighting)
    url << "&hl=false"

    json = SolrRequest.send_query(url)
    docs = SolrRequest.parse_docs(json)
    return docs, json["response"]["numFound"]
  end


  # The goal is to mimic advanced search journal filter on the ambra side (journal site)
  # 1. use fq (filter query) with cross_published_journal_key field
  # 2. display the journal names that are tied to the cross_published_journal_key field on the front end
  # There wasn't a way to tie cross_published_journal_key field values to cross_published_journal_name values 
  # easily without matching them up by hand
  def self.get_journal_name_key
    params = {}
    params[:q] = "*:*"
    params[:facet] = "true"
    params["facet.field"] = "cross_published_journal_key"
    params["facet.mincount"] = 1
    params[:rows] = 0
    params[:wt] = "json"

    url = "#{APP_CONFIG["solr_url"]}?#{params.to_param}&#{@@FILTER}"
    json = send_query(url)

    journal_keys = json["facet_counts"]["facet_fields"]["cross_published_journal_key"]
    journal_keys = journal_keys.values_at(* journal_keys.each_index.select {|i| i.even?})

    journals = []
    if (!APP_CONFIG["journals"].nil? && APP_CONFIG["journals"].size > 0)
      journal_keys.each do | journal_key |
        journal_name = APP_CONFIG["journals"][journal_key]
        journals << {:journal_name => APP_CONFIG["journals"][journal_key], :journal_key => journal_key} if !journal_name.nil?
      end
    end

    return journals
  end


  def self.get_now
    return Time.new
  end


  # Logic for creating a limit on the publication_date for a query.  All params are strings.
  # Legal values for days_ago are "-1", "0", or a positive integer.  If -1, the method
  # returns (nil, nil) (no date range specified).  If 0, the values of start_date and end_date
  # are used to construct the returned range.  If positive, the range extends from
  # (today - days_ago) to today.  start_date and end_date, if present, should be strings in the
  # format %m-%d-%Y.
  def self.parse_date_range(days_ago, start_date, end_date)
    days_ago = days_ago.to_i
    end_time = get_now
    if days_ago == -1  # All time; default.  Nothing to do.
      return nil, nil
      
    elsif days_ago == 0  # Custom date range
      start_time = Date.strptime(start_date, "%m-%d-%Y")
      end_time = DateTime.strptime(end_date + " 23:59:59", "%m-%d-%Y %H:%M:%S")
      
    else  # days_ago specifies start date; end date now
      start_time = end_time - (3600 * 24 * days_ago)
    end
    return start_time, end_time
  end

  
  # Returns a legal value constraining the publication_date solr field for the given start and
  # end DateTimes.  Returns nil if either of the arguments are nil.
  def self.build_date_range(start_date, end_date)
    if start_date.nil? || end_date.nil?
      return nil
    else
      return "[#{start_date.strftime(@@SOLR_TIMESTAMP_FORMAT)} " \
          "TO #{end_date.strftime(@@SOLR_TIMESTAMP_FORMAT)}]"
    end
  end
  
  # There are a handful of special cases where we want to display a "massaged"
  # version of what solr returns, instead of the direct value.  This method
  # takes care of all of those.
  def self.fix_data(doc)
    if doc["publication_date"]
      doc["publication_date"] = Date.strptime(doc["publication_date"], @@SOLR_TIMESTAMP_FORMAT)
    end
    
    # For articles cross-published in PLOS Collections, we want to display the
    # original journal name throughout the app.
    if doc["cross_published_journal_name"] && doc["cross_published_journal_name"].length > 1
      collections_index = doc["cross_published_journal_name"].index("PLOS Collections")
      if !collections_index.nil?
        new_index = collections_index == 0 ? 1 : 0
        doc["cross_published_journal_name"][0] = doc["cross_published_journal_name"][new_index]
      end
    end
    doc
  end

  # helper function for retrieving data from solr
  def self.get_data_helper(report_dois, cache_postfix, fields_to_retrieve)
    # TODO should we return emtpy array or nil if report_dois is nil / empty?
    
    all_results = {}
    if (report_dois.first.kind_of? String)
      dois = report_dois.clone
    else
      dois = report_dois.map { |report_doi| report_doi.doi }
    end

    # get solr data from cache
    if (!cache_postfix.nil?)
      dois.delete_if  do | doi |
        results = Rails.cache.read("#{doi}.#{cache_postfix}")
        if !results.nil?
          all_results[doi] = results
          true
        end
      end
    end

    while dois.length > 0 do
      subset_dois = dois.slice!(0, APP_CONFIG["solr_max_dois_per_request"])
      q = subset_dois.map { | doi | "id:\"#{doi}\"" }.join(" OR ")
  
      url = "#{APP_CONFIG["solr_url"]}?q=#{URI::encode(q)}&#{@@FILTER}&fl=#{fields_to_retrieve}" \
          "&wt=json&facet=false&rows=#{subset_dois.length}"

      json = SolrRequest.send_query(url)

      docs = json["response"]["docs"]
      docs.each do |doc|
        doc = fix_data(doc)
        all_results[doc["id"]] = doc
  
        # store solr data in cache
        if (!cache_postfix.nil?)
          Rails.cache.write("#{doc["id"]}.#{cache_postfix}", doc, :expires_in => 1.day)
        end
      end
    end

    return all_results
  end


  # Retrieves article related information from solr for a given list of DOIs.
  def self.get_data_for_articles(report_dois)
    return SolrRequest.get_data_helper(report_dois, "solr", @@FL)
  end

  # Retrieves alm data from solr for a given list of DOIs
  def self.get_data_for_viz(report_dois)
    start_time = Time.now

    data = SolrRequest.get_data_helper(report_dois, nil, @@FL_METRIC_DATA)

    end_time = Time.now
    Rails.logger.debug "SOLR Data for Viz Request for #{report_dois.size} articles took " \
        "#{end_time - start_time} seconds."

    return data

  end

  def self.validate_dois(report_dois)
    start_time = Time.now
    
    data = SolrRequest.get_data_helper(report_dois, nil, @@FL_VALIDATE_ID)

    end_time = Time.now
    Rails.logger.debug "SOLR Validate Dois Request for #{report_dois.size} articles took " \
        "#{end_time - start_time} seconds."

    return data

  end

  
  # Performs a batch query for articles based on the list of PubMed IDs passed in.
  # Returns a hash of PMID => solr doc, with only id, pmid, and publication_date defined
  # in the solr docs.
  def self.query_by_pmids(pmids)
    q = pmids.map {|pmid| "pmid:\"#{pmid}\""}.join(" OR ")
    url = "#{APP_CONFIG["solr_url"]}?q=#{URI::encode(q)}&#{@@FILTER}" \
        "&fl=id,publication_date,pmid&wt=json&facet=false&rows=#{pmids.length}"
    json = SolrRequest.send_query(url)
    docs = json["response"]["docs"]
    results = {}
    docs.each do |doc|
      if doc["publication_date"]
        doc["publication_date"] = Date.strptime(doc["publication_date"], @@SOLR_TIMESTAMP_FORMAT)
      end
      results[doc["pmid"].to_i] = doc
    end
    results
  end

end
