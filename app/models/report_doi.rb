class ReportDoi < ActiveRecord::Base
  belongs_to :report
  attr_accessible :doi, :sort_order
  attr_accessor :solr, :alm, :display_index

end
