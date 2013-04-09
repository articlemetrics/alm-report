class Report < ActiveRecord::Base
  attr_accessible :user_id
  
  # TODO: figure out what we want the default sort order to be.
  # doi is likely not a good solution.
  has_many :report_dois, :order => 'doi'
  
  
  # Loads solr data for each article in this report.
  def load_articles_from_solr
    
    # TODO: something more efficient.  Bulk query?  Caching?  Both?
    report_dois.each {|report_doi| report_doi.load_from_solr}
  end
  
  
  # Sets the @sorted_report_dates field.
  # Precondition: load_articles_from_solr has already been called.
  def sort_report_dates
    if @sorted_report_dates.nil?
      @sorted_report_dates = report_dois.collect{|report_doi| report_doi.solr["publication_date"]}
      @sorted_report_dates.sort!
    end
  end
  private :sort_report_dates
  
  
  # Returns the earliest publication date of any article in this report.
  # Precondition: load_articles_from_solr has already been called.
  def get_earliest_report_date
    sort_report_dates
    @sorted_report_dates[0]
  end
  
  
  # Returns the latest publication date of any article in this report.
  # Precondition: load_articles_from_solr has already been called.
  def get_latest_report_date
    sort_report_dates
    @sorted_report_dates[-1]
  end
  
end
