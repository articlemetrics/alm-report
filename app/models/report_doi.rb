class ReportDoi < ActiveRecord::Base
  belongs_to :report
  attr_accessible :doi
end
