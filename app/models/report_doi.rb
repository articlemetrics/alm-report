class ReportDoi < ActiveRecord::Base
  belongs_to :report
  attr_accessible :doi, :sort_order
  attr_accessor :solr, :alm, :display_index
  
  # Returns true if this ReportDoi corresponds to a PLOS Currents article, and
  # false otherwise.
  def is_currents_doi
    BackendService.is_currents_doi(doi)
  end

end
