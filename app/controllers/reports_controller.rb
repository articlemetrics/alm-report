class ReportsController < ApplicationController

  # Creates a new report based on the DOIs stored in the session, and redirects to
  # display it.
  def generate
    dois = session[:dois]
    if dois.nil? || dois.length == 0

      # We don't need to give a polite message to the user, since the link
      # to this action shouldn't be visible if they have no articles in
      # the session.
      raise "No DOIs saved in session!"
    end

    @report = Report.new
    if !@report.save
      raise "Error saving report"
    end

    # Convert to array, sorted in descending order by timestamp, then throw away the timestamps.
    dois = dois.sort_by{|doi, timestamp| -timestamp}.collect{|x| x[0]}
    @report.add_all_dois(dois)
    if @report.save
      redirect_to :action => "metrics", :id => @report.id
    else
      # TODO
    end
  end


  # Loads a report based on the report_id, and sets some other common variables used by
  # the reports pages.
  def load_report(id)
    @tab = :view_report
    @report = Report.find(id)

    # Save the report DOIs in the session (overwriting whatever might already be there).
    @saved_dois.clear
    @report.report_dois.each do |report_doi|
      @saved_dois[report_doi.doi] = report_doi.sort_order
    end
  end


  def metrics
    load_report(params[:id])
    @report_sub_tab = :metrics
    @title = "Report Metrics"
    
    paging_logic = lambda {
      @total_found = @report.report_dois.length
      set_paging_vars(params[:current_page], APP_CONFIG["metrics_results_per_page"])

      # Create a new array for display that is only the articles on the current page,
      # to limit what we have to load from solr and ALM.
      @dois = @report.report_dois[(@start_result) - 1..(@end_result - 1)]
      alm_data = AlmRequest.get_data_for_articles(@dois)
      solr_data = BackendService.get_article_data_for_list_display(@dois)
      [solr_data, alm_data]
    }

    @show_metrics_data = true
    if @report.report_dois.length > 0
      solr_data, alm_data = paging_logic.call()
      i = @start_result
      dois_to_delete = manage_report_data(@dois, solr_data, alm_data, i)
      if (!dois_to_delete.empty?)
        purge_bad_dois(dois_to_delete)
        
        # We need to re-do paging logic since the number of articles has changed.
        solr_data, alm_data = paging_logic.call()
        i = @start_result
        manage_report_data(@dois, solr_data, alm_data, i)
      end
    else
      @show_metrics_data = false
    end
  end

  
  # Permanently removes the given DOIs from a report.
  def purge_bad_dois(dois_to_delete)
    logger.warn("Nonexistent DOIs detected; will delete from report: #{@report.id}: #{dois_to_delete.inspect}")

    # delete the bad dois from the report
    ReportDoi.destroy_all(:id => dois_to_delete)
    @report.reload
  end


  def visualizations
    load_report(params[:id])
    if @report.report_dois.length > APP_CONFIG["viz_limit"]
      raise "Visualizations not enabled for more than #{APP_CONFIG["viz_limit"]} reports"
    end
    @report_sub_tab = :visualizations
    @title = "Report Visualizations"

    # deteremine if the report contains only one article
    one_article_report = false
    if (@report.report_dois.length == 1) 
      one_article_report = true
      alm_data = AlmRequest.get_data_for_one_article(@report.report_dois)
    else
      alm_data = AlmRequest.get_data_for_viz(@report.report_dois)
    end

    solr_data = BackendService.get_article_data_for_list_display(@report.report_dois)

    dois_to_delete = manage_report_data(@report.report_dois, solr_data, alm_data)

    if (!dois_to_delete.empty?)
      purge_bad_dois(dois_to_delete)

      # TODO fix sort order

      manage_report_data(@report.report_dois, solr_data, alm_data)
    end

    @draw_viz = true
    if (one_article_report && @report.report_dois.length == 1)
      #render single article report
      @article_usage_data = ChartData.generate_data_for_usage_chart(@report)
      @article_citation_data = ChartData.generate_data_for_citation_chart(@report)

      social_scatter_data = ChartData.generate_data_for_social_data_chart(@report)
      @social_scatter_header = social_scatter_data[:column_header]
      @social_scatter = social_scatter_data[:data]

      mendeley_reader_data = ChartData.generate_data_for_mendeley_reader_chart(@report)
      @reader_data = mendeley_reader_data[:reader_loc_data]
      @reader_total = mendeley_reader_data[:reader_total]

      render 'visualization.html.erb'
    else
      @is_currents_only = true
      @report.report_dois.each do |report_doi|
        if !report_doi.is_currents_doi
          @is_currents_only = false
          break
        end
      end
      
      # this covers situations where a report contains many articles but very small
      # portion of the articles have alm data  (without alm data, viz page will look very weird)
      if solr_data.length >= APP_CONFIG["visualization_min_num_of_alm_data_points"]

        bubble_data = ChartData.generate_data_for_bubble_charts(@report)
        @article_usage_citations_age_data = bubble_data[:citation_data]
        @article_usage_mendeley_age_data = bubble_data[:mendeley_data]

        @article_usage_citation_subject_area_data = ChartData.generate_data_for_subject_area_chart(@report)
        
        loc_data = ChartData.generate_data_for_articles_by_location_chart(@report)
        @total_authors_data = loc_data[:total_authors_data]
        @article_locations_data = loc_data[:locations_data]
      else
        @draw_viz = false
      end
      render 'visualizations.html.erb'
    end
  end


  def manage_report_data(report_dois, solr_data, alm_data, display_start_index = 1)

    i = display_start_index
    dois_to_delete = []

    report_dois.each do |doi|
      solr = solr_data[doi.doi]

      if solr.nil?
        dois_to_delete << doi.id
      else
        doi.solr = solr

        # only try to retrieve the alm data if the article exists in solr
        alm = alm_data[doi.doi]

        if alm.nil?
          # if there isn't alm data for an article that exists in solr
          # alm had an error for that article or 
          # the article is too new to have any alm data
          # either way, display an error message
        else
          doi.alm = alm
        end
      end

      
      # Set the display index as a property for rendering.
      doi.display_index = i
      i += 1
    end

    return dois_to_delete

  end


  # handles download data links
  def download_data
    load_report(params[:id])
    options = {}
    if (params[:field])
      options[:field] = params[:field]
    end

    filename = (params[:field] == "doi") ? "doilist.csv" : "almreport.csv"

    respond_to do | format |
      format.csv { send_data @report.to_csv(options), :filename => filename }
    end
  end

end
