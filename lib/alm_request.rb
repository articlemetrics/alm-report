require "net/http"
require "open-uri"
require "json"

# Interface to the PLOS ALM API.
class AlmRequest
  
  @@URL = "http://alm.plos.org/articles"
  
  
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
  
end
