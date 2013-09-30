require "net/http"
require "open-uri"
require "json"

# Interface to the PLOS ALM API.
module AlmRequest
  
  
  # Retrieves and returns all ALM data for the given DOIs.  Multiple requests to ALM
  # may be made if the number of DOIs is large.  The returned list is the raw JSON
  # output from ALM, with no additional processing.
  def self.get_raw_data(dois)
    json = []
    while dois.length > 0 do
      subset_dois = dois.slice!(0, APP_CONFIG["alm_max_articles_per_request"])
      params = {}
      params[:ids] = subset_dois.join(",")

      # ALM will return all the data it can in the list of articles.
      # the only ones missing will be omitted from the response.
      # if it only has one article and it fails to retrieve data for that one article, 
      # that's when it will return 404

      url = get_alm_url(params)

      start_time = Time.now

      resp = Net::HTTP.get_response(URI.parse(url))

      end_time = Time.now
      Rails.logger.debug "ALM Request for #{subset_dois.size} articles took #{end_time - start_time} seconds"

      if !resp.kind_of?(Net::HTTPSuccess)
        Rails.logger.error "ALM Server for #{url} returned #{resp.code}: " + resp.body

        # move to the next set of articles
        next
      end
      json.concat(JSON.parse(resp.body))
    end
    json
  end
  
  
  # Checks memcache to see if data about the given DOIs are present.
  #
  # Params:
  #   dois: list of DOIs to check
  #   cache_results: dict that will be filled with results from the cache.  The
  #     key will be doi, and the value the result found in the cache.
  #   cache_suffix: the suffix to append to the DOI to generate a cache key
  #
  # Returns: all DOIs that were *not* found in the cache
  def self.check_cache(dois, cache_results, cache_suffix)
    dois.delete_if  do | doi |
      results = Rails.cache.read("#{doi}.#{cache_suffix}")
      if !results.nil?
        cache_results[doi] = results
        true
      end
    end
    dois
  end


  # Returns a dict containing ALM usage data for a given list of articles.
  def self.get_data_for_articles(report_dois)
    all_results = {}
    dois = report_dois.map { |report_doi| report_doi.doi }

    # get alm data from cache
    dois = check_cache(dois, all_results, "alm")
    
    json = AlmRequest.get_raw_data(dois)
    json.each do | article |
      sources = article["sources"].map { | source | ([source["name"], source["metrics"]]) }
      sources_dict = Hash[*sources.flatten(1)]

      results = {}

      results[:plos_html] = sources_dict["counter"]["html"].to_i
      results[:plos_pdf] = sources_dict["counter"]["pdf"].to_i
      results[:plos_xml] = sources_dict["counter"]["total"].to_i - (results[:plos_html] + results[:plos_pdf])
      results[:plos_total] = sources_dict["counter"]["total"].to_i

      results[:pmc_views] = sources_dict["pmc"]["html"].to_i
      results[:pmc_pdf] = sources_dict["pmc"]["pdf"].to_i
      results[:pmc_total] = results[:pmc_views] + results[:pmc_pdf]

      results[:total_usage] = results[:plos_html] + results[:plos_pdf] + results[:plos_xml] + results[:pmc_views] + results[:pmc_pdf]
      results[:viewed_data_present] = (results[:total_usage] > 0)

      results[:pmc_citations] = sources_dict["pubmed"]["total"].to_i
      results[:crossref_citations] = sources_dict["crossref"]["total"].to_i
      results[:scopus_citations] = sources_dict["scopus"]["total"].to_i
      results[:cited_data_present] = (results[:pmc_citations] + results[:crossref_citations] + results[:scopus_citations]) > 0

      results[:citeulike] = sources_dict["citeulike"]["total"].to_i
      # removing connotea
      # results[:connotea] = sources_dict["connotea"]["total"].to_i
      results[:mendeley] = sources_dict["mendeley"]["total"].to_i
      results[:saved_data_present] = (results[:citeulike] + results[:mendeley]) > 0

      results[:nature] = sources_dict["nature"]["total"].to_i
      results[:research_blogging] = sources_dict["researchblogging"]["total"].to_i
      results[:scienceseeker] = sources_dict["scienceseeker"]["total"].to_i
      results[:facebook] = sources_dict["facebook"]["total"].to_i
      results[:twitter] = sources_dict["twitter"]["total"].to_i
      results[:wikipedia] = sources_dict["wikipedia"]["total"].to_i
      results[:discussed_data_present] = (results[:nature] + results[:research_blogging] + results[:wikipedia] + results[:scienceseeker] + results[:facebook] + results[:twitter]) > 0        

      all_results[article["doi"]] = results

      # store alm data in cache
      Rails.cache.write("#{article["doi"]}.alm", results, :expires_in => 1.day)
    end
    all_results
  end
  
  # Retrieves article data from ALM suitable for display in a brief list, such
  # as search results or the preview list.
  #
  # Note that most of the time, you'll want to get this data from solr via
  # SolrRequest.get_data_for_articles.  The exception is PLOS Currents articles,
  # which are not currently in solr.
  def self.get_article_data_for_list_display(dois)
    results = {}
    dois = check_cache(dois, results, "alm_list_display")
    json = AlmRequest.get_raw_data(dois)
    json.each do |article|
      results[article["doi"]] = article
      Rails.cache.write("#{article["doi"]}.alm_list_display", article, :expires_in => 1.day)
    end
    results
  end
  
  # Gathers ALM data for visualization for a given list of dois
  # If the list of dois exceed certain size, the data will be retrieved from solr
  # (for performance reasons)
  #
  # the alm data that's retrieved from solr will not be cached.  Alm data in solr
  # is at most 1 day behind the data in alm application and the app should not cache data that's
  # already 1 day behind
  def self.get_data_for_viz(report_dois)

    # TODO future: only count the articles that are not cached when comparing the # of articles to retrieve alm data for

    if report_dois.size > APP_CONFIG["alm_max_size_for_realtime"]

      # get alm data from solr
      metric_data = SolrRequest.get_data_for_viz(report_dois)

      all_results = {}

      metric_data.each_pair do | doi, data |
        # make the data look like what it would have looked like if the data was retrieved from alm

        results = {}

        results[:total_usage] = data["counter_total_all"].to_i + data["alm_pmc_usage_total_all"].to_i
        results[:scopus_citations] = data["alm_scopusCiteCount"].to_i
        results[:mendeley] = data["alm_mendeleyCount"].to_i

        all_results[doi] = results
      end

      return all_results

    else
      # get alm data from alm
      return self.get_data_for_articles(report_dois)
    end
  end

  # get data for single article visualization report
  def self.get_data_for_one_article(report_dois)
    dois = report_dois.map { |report_doi| report_doi.doi }

    params = {}
    params[:ids] = dois.join(",")
    params[:info] = "history"
    params[:source] = "crossref,pubmed,scopus"

    url = get_alm_url(params)
    
    resp = Net::HTTP.get_response(URI.parse(url))

    all_results = {}

    if !resp.kind_of?(Net::HTTPSuccess)
      Rails.logger.error "ALM Server for #{url} returned #{resp.code}: " + resp.body

      return all_results
    end

    data = JSON.parse(resp.body)

    data.each do | article |
      results = {}

      results = article["sources"].inject({}) do | result, source |
        key = source["name"].to_sym
        result[key] = {}
        result[key][:histories] = source["histories"]
        result[key][:total] = source["metrics"]["total"].to_i
        result
      end

      results[:publication_date] = article["publication_date"]

      all_results[article["doi"]] = results
    end

    params = {}
    params[:ids] = dois.join(",")
    params[:info] = "event"
    params[:source] = "counter,pmc,citeulike,twitter,researchblogging,nature,scienceseeker,mendeley"

    url = get_alm_url(params)
    
    resp = Net::HTTP.get_response(URI.parse(url))

    if !resp.kind_of?(Net::HTTPSuccess)
      Rails.logger.error "ALM Server for #{url} returned #{resp.code}: " + resp.body

      return all_results
    end

    data = JSON.parse(resp.body)

    data.each do | article |
      results = all_results[article["doi"]]

      article["sources"].inject(results) do | result, source |
        key = source["name"].to_sym
        result[key] = {}
        result[key][:events] = source["events"]
        result[key][:total] = source["metrics"]["total"].to_i
        result
      end

      all_results[article["doi"]] = results
    end    

    return all_results
  end

  # Params are the parameters to be used to query for alm data
  def self.get_alm_url(params)
    url = ""
    if (!params.nil? && params.length > 0)
      url = "#{APP_CONFIG["alm_url"]}/?api_key=#{APP_CONFIG["alm_api_key"]}&#{params.to_param}"
    end
    return url
  end
end
