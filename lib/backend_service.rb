
# Facade that represents all backend services that the application talks to.
#
# Note that currently a lot of the controllers bypass this, and call directly
# to AlmRequest or SolrRequest.
class BackendService
  
  # Given a list of DOIs, returns a dict from doi to an object containing
  # all fields necessary for displaying in an article list, such as is
  # used for search results and the preview list.
  def self.get_article_data_for_list_display(dois)
    solr_dois = []
    alm_dois =  []
    dois.each do |doi|
      
      # PLOS Currents articles aren't in solr, so we get what data we can from
      # ALM instead.
      if BackendService.is_currents_doi(doi)
        alm_dois << doi
      else
        solr_dois << doi
      end
    end
    results = {}
    if !solr_dois.empty?
      results.merge!(SolrRequest.get_data_for_articles(solr_dois))
    end
    if !alm_dois.empty?
      alm_data = AlmRequest.get_article_data_for_list_display(alm_dois)
      alm_data.each do |doi, article|
        
        # In order to "fool" view code into believing that these results are
        # coming from solr, we have to message some data...
        article["id"] = doi
        article["publication_date"] = Date.strptime(article["publication_date"],
            SolrRequest.SOLR_TIMESTAMP_FORMAT)
        article["cross_published_journal_name"] = ["PLOS Currents"]
        results[doi] = article
      end
    end
    results
  end
  
  
  # Returns true if the DOI string identifies a PLOS Currents article, false otherwise.
  #
  # TODO: consider moving this somewhere more appropriate.
  def self.is_currents_doi(doi)
    %r|10\.1371/currents\.\S+| =~ doi
    return $~.nil? ? false : true
  end
  
end
