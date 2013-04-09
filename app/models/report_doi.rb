class ReportDoi < ActiveRecord::Base
  belongs_to :report
  attr_accessible :doi
  attr_reader :solr, :alm
  
  
  # Loads data from solr related to this article, and stores it in the solr
  # attribute.
  def load_from_solr
    @solr = SolrRequest.get_article(doi)
  end
  
  
  # Loads data from ALM related to this article, and stores it in the alm
  # attribute.
  def load_from_alm
    @alm = AlmRequest.get_article_data(doi)
  end

end
