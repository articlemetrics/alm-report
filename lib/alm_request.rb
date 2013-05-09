require "net/http"
require "open-uri"
require "json"

# Interface to the PLOS ALM API.
module AlmRequest
  
  # TODO add this to the config file, not hardcoded
  @@URL = "http://alm.plos.org/api/v3/articles"


  # Returns a dict containing ALM usage data for a given list of articles.
  def self.get_data_for_articles(report_dois)

    all_results = {}

    dois = report_dois.map { |report_doi| report_doi.doi }

    # get alm data from cache
    dois.delete_if  do | doi |
      results = Rails.cache.read("#{doi}.alm")
      if !results.nil?
        all_results[doi] = results
        true
      end
    end

    # https://github.com/articlemetrics/alm/wiki/API
    # Queries for up to 50 articles at a time are supported.
    # TODO configure
    num_articles = 30
    while dois.length > 0 do
      subset_dois = dois.slice!(0, num_articles)
      params = {}
      params[:ids] = subset_dois.join(",")

      # ALM will return all the data it can in the list of articles.
      # the only ones missing will be omitted from the response.
      # if it only has one article and it fails to retrieve data for that one article, 
      # that's when it will return 404

      url = "#{@@URL}/?#{params.to_param}"

      start_time = Time.now

      resp = Net::HTTP.get_response(URI.parse(url))

      end_time = Time.now
      Rails.logger.debug "ALM Request for #{subset_dois.size} articles took #{end_time - start_time} seconds"

      if !resp.kind_of?(Net::HTTPSuccess)
        Rails.logger.error "ALM Server for #{url} returned #{resp.code}: " + resp.body

        # move to the next set of articles
        next
      end

      json = JSON.parse(resp.body)

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
        results[:usage_data_present] = (results[:total_usage] > 0)

        results[:pmc_citations] = sources_dict["pubmed"]["total"].to_i
        results[:crossref_citations] = sources_dict["crossref"]["total"].to_i
        results[:scopus_citations] = sources_dict["scopus"]["total"].to_i
        results[:citation_data_present] = (results[:pmc_citations] + results[:crossref_citations] + results[:scopus_citations]) > 0

        results[:citeulike] = sources_dict["citeulike"]["total"].to_i
        results[:connotea] = sources_dict["connotea"]["total"].to_i
        results[:mendeley] = sources_dict["mendeley"]["total"].to_i
        results[:twitter] = sources_dict["twitter"]["total"].to_i
        results[:facebook] = sources_dict["facebook"]["total"].to_i
        results[:social_network_data_present] = (results[:citeulike] + results[:connotea] + results[:mendeley] + results[:twitter] + results[:facebook]) > 0

        results[:nature] = sources_dict["nature"]["total"].to_i
        results[:research_blogging] = sources_dict["researchblogging"]["total"].to_i
        results[:wikipedia] = sources_dict["wikipedia"]["total"].to_i
        results[:blogs_data_present] = (results[:nature] + results[:research_blogging] + results[:wikipedia]) > 0

        results[:scienceseeker] = sources_dict["scienceseeker"]["total"].to_i

        all_results[article["doi"]] = results

        # store alm data in cache
        Rails.cache.write("#{article["doi"]}.alm", results, :expires_in => 1.day)
      end
    end

    return all_results
  end
  
  # Gathers ALM data for visualization for a given list of dois
  # If the list of dois exceed certain size, the data will be retrieved from solr
  # (for performance reasons)
  #
  # the alm data that's retrieved from solr will not be cached.  Alm data in solr
  # is at most 1 day behind the data in alm application and the app should not cache data that's
  # already 1 day behind
  def self.get_data_for_viz(report_dois)

    # TODO configure size
    max_size_for_realtime = 20

    # TODO future: only count the articles that are not cached when comparing the # of articles to retrieve alm data for

    if report_dois.size > max_size_for_realtime

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

end
