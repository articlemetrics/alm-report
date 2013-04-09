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
    @total_found = @report.report_dois.length
    set_paging_vars(params[:current_page], 5)
    
    # Create a new array for display that is only the articles on the current page,
    # to limit what we have to load from solr and ALM.
    @dois = @report.report_dois[(@start_result) - 1..(@end_result - 1)]
    i = @start_result
    @dois.each do |doi|
      doi.load_from_solr
      doi.load_from_alm
      
      # Set the display index as a property for rendering.
      doi[:display_index] = i
      i += 1
    end
  end
  
  
  def visualizations
    @tab = :view_report
    @report_sub_tab = :visualizations
    @report = Report.find(params[:id])
    @report.load_articles_from_solr
  end
  
end
