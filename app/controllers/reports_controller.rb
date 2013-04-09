class ReportsController < ApplicationController

  # Creates a new report based on the DOIs stored in the session, and redirects to
  # display it.
  def generate
    dois = session[:dois]
    if dois.nil?
      
      # TODO: user-friendly error handling
      raise "No DOIs saved in session!"
    end

    @report = Report.new
    if !@report.save
      raise "Error saving report"
    end
    dois.each {|doi| @report.report_dois.create(:doi => doi)}
    
    if @report.save
      redirect_to :action => "metrics", :id => @report.id
    else
      
      # TODO
    end
  end
  
  
  def metrics
    @tab = :view_report
    @report_sub_tab = :metrics
    @report = Report.find(params[:id])
    
    # TODO: sort in a better way than alphabetically by DOI?
    dois = @report.report_dois.collect{|report_doi| report_doi.doi}.sort
    @total_found = dois.length
    set_paging_vars(params[:current_page], 5)
    dois = dois[(@start_result) - 1..(@end_result - 1)]
    
    @docs = []
    i = @start_result
    dois.each do |doi|
      
      # TODO: same TODOs as HomeController.preview_list.  Cache results from solr.
      doc = SolrRequest.get_article(doi)
      
      # TODO: cache results from ALM
      doc[:alm_data] = AlmRequest.get_article_data(doi)
      
      # Set the display index as a property on the doc for rendering.
      doc[:display_index] = i
      i += 1
      @docs << doc
    end
  end
  
  
  def visualizations
    @tab = :view_report
    @report_sub_tab = :visualizations
    @report = Report.find(params[:id])
    
    # TODO
    
  end
  
end
