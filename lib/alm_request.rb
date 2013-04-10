require "net/http"
require "open-uri"
require "json"

# Interface to the PLOS ALM API.
module AlmRequest
  
  # TODO add this to the config file, not hardcoded
  @@URL = "http://alm.plos.org/api/v3/articles"
  
  
  # Processes the "Counter" data source and returns a tuple of (HTML views, PDF views, XML views)
  # for a given article.
  def self.aggregate_plos_views(plos_source)
    views = 0
    pdfs = 0
    xmls = 0
    plos_source["events"].each do |event|
      views += event["html_views"].to_i
      pdfs += event["pdf_views"].to_i
      xmls += event["xml_views"].to_i
    end
    return views, pdfs, xmls
  end
  
  
  # Processes the "PubMed Central Usage Stats" data source and returns a tuple of
  # (HTML views, PDF views) for a given article.
  def self.aggregate_pmc_views(pmc_source)
    views = 0
    pdf = 0
    if pmc_source["events"]
      pmc_source["events"].each do |event|
        views += event["full-text"].to_i
        pdf += event["pdf"].to_i
      end
    end
    return views, pdf
  end


  # Returns a dict containing ALM usage data for a given article.
  def self.get_article_data(doi)
    url = "#{@@URL}/#{URI::encode(doi)}.json?events=1"
    resp = Net::HTTP.get_response(URI.parse(url))
    if resp.code != "200"
      raise "Server returned #{resp.code}: " + resp.body
    end
    json = JSON.parse(resp.body)
    
    # json["article"]["source"] is a list of all sources; convert to a dict keyed
    # by source name for convenience.
    sources = json["article"]["source"].collect{|source| [source["source"], source]}
    sources_dict = Hash[*sources.flatten]
    
    plos_html, plos_pdf, plos_xml = aggregate_plos_views(sources_dict["Counter"])
    results = {}
    results[:plos_html] = plos_html
    results[:plos_pdf] = plos_pdf
    results[:plos_xml] = plos_xml
    
    pmc_views, pmc_pdf = aggregate_pmc_views(sources_dict["PubMed Central Usage Stats"])
    results[:pmc_views] = pmc_views
    results[:pmc_pdf] = pmc_pdf
    
    results[:total_usage] = plos_html + plos_pdf + plos_xml + pmc_views + pmc_pdf
    results[:usage_data_present] = (results[:total_usage] > 0)
    
    pmc_citations = sources_dict["PubMed Central"]["count"].to_i
    results[:pmc_citations] = pmc_citations
    crossref_citations = sources_dict["CrossRef"]["count"].to_i
    results[:crossref_citations] = crossref_citations
    scopus_citations = sources_dict["Scopus"]["count"].to_i
    results[:scopus_citations] = scopus_citations
    results[:citation_data_present] = (pmc_citations + crossref_citations + scopus_citations) > 0
    
    citulike = sources_dict["CiteULike"]["count"].to_i
    results[:citeulike] = citulike
    connotea = sources_dict["Connotea"]["count"].to_i
    results[:connotea] = connotea
    mendeley = sources_dict["Mendeley"]["count"].to_i
    results[:mendeley] = mendeley
    twitter = sources_dict["Twitter"]["count"].to_i
    results[:twitter] = twitter
    facebook = sources_dict["Facebook"]["count"].to_i
    results[:facebook] = facebook
    results[:social_network_data_present] = (citulike + connotea + mendeley + twitter + facebook) > 0
    
    nature = sources_dict["Nature"]["count"].to_i
    results[:nature] = nature
    research_blogging = sources_dict["Research Blogging"]["count"].to_i
    results[:research_blogging] = research_blogging
    wikipedia = sources_dict["Wikipedia"]["count"].to_i
    results[:wikipedia] = wikipedia
    results[:blogs_data_present] = (nature + research_blogging + wikipedia) > 0
    
    # TODO: caching
    return results
  end


  def self.get_data_for_articles(report_dois)
    # TODO 50 articles at a time
    dois = report_dois.map { |report_doi| report_doi.doi }
    params = {}
    params[:ids] = dois.join(",")
    params[:info] = 'event'

    url = "#{@@URL}/?#{params.to_param}"

    puts "#{url}"

    resp = Net::HTTP.get_response(URI.parse(url))

    # TODO check http response

    json = JSON.parse(resp.body)

    all_results = {}
    json.each do | article |
      sources = article["sources"].map { | source | [source["name"], source["metrics"]] }
      sources_dict = Hash[*sources.flatten]

      results = {}

      # TODO waiting for an alm bug to be fixed
      results[:plos_html] = sources_dict["counter"]["html"]
      results[:plos_pdf] = sources_dict["counter"]["pdf"]
      # TODO get xml data
      results[:plos_xml] = 0

      results[:pmc_views] = sources_dict["pmc"]["html"]
      results[:pmc_pdf] = sources_dict["pmc"]["pdf"]

      results[:total_usage] = results[:plos_html] + results[:plos_pdf] + results[:plos_xml] + results[:pmc_views] + results[:pmc_pdf]
      results[:usage_data_present] = (results[:total_usage] > 0)

      results[:pmc_citations] = sources_dict["pubmed"]["total"]
      results[:crossref_citations] = sources_dict["crossref"]["total"]
      results[:scopus_citations] = sources_dict["scopus"]["total"]
      results[:citation_data_present] = (results[:pmc_citations] + results[:crossref_citations] + results[:scopus_citations]) > 0

      results[:citeulike] = sources_dict["citeulike"]["total"]
      results[:connotea] = sources_dict["connotea"]["total"]
      results[:mendeley] = sources_dict["mendeley"]["total"]
      results[:twitter] = sources_dict["twitter"]["total"]
      results[:facebook] = sources_dict["facebook"]["total"]
      results[:social_network_data_present] = (results[:citeulike] + results[:connotea] + results[:mendeley] + results[:twitter] + results[:facebook]) > 0

      results[:nature] = sources_dict["nature"]["total"]
      results[:research_blogging] = sources_dict["researchblogging"]["total"]
      results[:wikipedia] = sources_dict["wikipedia"]["total"]
      results[:blogs_data_present] = (results[:nature] + results[:research_blogging] + results[:wikipedia]) > 0

      all_results[article["doi"]] = results
    end

    return all_results
  end
  
end
