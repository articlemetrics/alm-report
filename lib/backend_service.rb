
require "set"

# Facade that represents all backend services that the application talks to.
#
# Note that currently a lot of the controllers bypass this, and call directly
# to AlmRequest or SolrRequest.
class BackendService
  
  # Given a list of DOIs, returns a dict from doi to an object containing
  # all fields necessary for displaying in an article list, such as is
  # used for search results and the preview list.
  def self.get_article_data_for_list_display(dois)
    if (dois.first.kind_of? String)
      dois = dois.clone
    else
      dois = dois.map {|report_doi| report_doi.doi}
    end
    
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
  
  
  # Most PLOS Currents articles have DOIs that begin with "10.1371/currents.", but a
  # few of the first ones do not.  In order to be able to do sane validation, we just
  # list the old ones here.
  LEGACY_CURRENTS_DOIS = [
      "10.1371/4f6cf3e8df15a",
      "10.1371/4facf9d99b997",
      "10.1371/4fb3fd97a2d3c",
      "10.1371/4f9f1fa9c3cae",
      "10.1371/4f8d4eaec6af8",
      "10.1371/4f93005fbcb34",
      "10.1371/4f83ebf72317d",
      "10.1371/4f7f57285b804",
      "10.1371/4fc33066f1947",
      "10.1371/4fa83b7576b6e",
      "10.1371/4fca9ee30afc4",
      "10.1371/4fbbbe1668eef",
      "10.1371/4f7b4bab0d1a3",
      "10.1371/4fdfb212d2432",
      "10.1371/50081cad5861d",
      "10.1371/5028b6037259a",
      "10.1371/5014b1b407653",
      "10.1371/4fd80324dd362",
      "10.1371/4fbbdec6279ec",
      "10.1371/4f959951cce2c",
      "10.1371/198d344bc40a75f927c9bc5024279815",
      "10.1371/50585b8e6efd1",
      "10.1371/4f9877ab8ffa9",
      "10.1371/4f9995f69e6c7",
      "10.1371/4f972cffe82c0",
      "10.1371/4fbca54a2028b",
      "10.1371/4f7f6dc013d4e",
      "10.1371/4fd085bfc9973",
      "10.1371/4f8606b742ef3",
      "10.1371/505886e9a1968",
      "10.1371/4f8c9a2e1fca8",
      "10.1371/500563f3ea181",
      "10.1371/4f99c5654147a",
      "10.1371/4f84a944d8930",
      "10.1371/4ffdff160de8b",
      "10.1371/5035add8caff4",
      "10.1371/4fd1286980c08",
      ].to_set
  
  
  # Returns true if the DOI string identifies a PLOS Currents article, false otherwise.
  #
  # TODO: consider moving this somewhere more appropriate.
  def self.is_currents_doi(doi)
    %r|10\.1371/currents\.\S+| =~ doi
    if $~.nil?
      return LEGACY_CURRENTS_DOIS.include?(doi)
    else
      return true
    end
  end
  
end
