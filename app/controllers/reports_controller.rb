class ReportsController < ApplicationController
  # Creates a new report based on the DOIs stored in the session,
  # and redirects to display it.
  def generate
    dois = @cart.items.keys
    # start again if we find no dois
    if dois.blank?
      return redirect_to(search_advanced_path,
                         unformattedQueryId: params[:unformattedQueryId],
                         filters: params[:filters])
    end

    @report = Report.new
    if !@report.save
      raise "Error saving report"
    end

    @report.add_all_dois(dois)
    if @report.save
      redirect_to :action => "metrics", :id => @report.id
    else
      # TODO
    end
  end

  # Loads a report based on the report_id, and sets some other common variables
  # used by the reports pages.
  def load_report(id)
    @tab = :view_report
    @report = Report.find(id)

    # Save the report DOIs in the session (overwriting whatever might already be there).
    @cart.clear
    @report.report_dois.each do |report_doi|
      @cart[report_doi.doi] = report_doi.sort_order
    end
  end

  def metrics
    load_report(params[:id])
    @report_sub_tab = :metrics
    @title = "Report Metrics"

    paging_logic = lambda {
      @total_found = @report.report_dois.length
      set_paging_vars(params[:current_page], ENV["METRICS_PER_PAGE"].to_i)

      # Create a new array for display that is only the articles on the current page,
      # to limit what we have to load from solr and ALM.
      @dois = @report.report_dois[(@start_result) - 1..(@end_result - 1)]
      alm_data = AlmRequest.get_data_for_articles(@dois)
      solr_data = Cart.new(@dois.map(&:doi))
      [solr_data, alm_data]
    }

    @show_metrics_data = true
    if @report.report_dois.length > 0
      @solr_data, @alm_data = paging_logic.call()
      i = @start_result
      dois_to_delete = manage_report_data(@dois, i)
      if (!dois_to_delete.empty?)
        purge_bad_dois(dois_to_delete)

        # We need to re-do paging logic since the number of articles has changed.
        @solr_data, @alm_data = paging_logic.call()
        i = @start_result
        manage_report_data(@dois, i)
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
    @report_sub_tab = :visualizations
    @title = "Report Visualizations"

    load_report(params[:id])

    if @report.report_dois.length > ENV["VIZ_LIMIT"].to_i
      return flash[:error] = "Visualizations not enabled for more than " \
        "#{ENV["VIZ_LIMIT"].to_i} reports"
    end
  end

  def manage_report_data(report_dois, display_start_index = 1)

    i = display_start_index
    dois_to_delete = []

    report_dois.each do |doi|
      solr = @solr_data[doi.doi]

      if solr.nil?
        dois_to_delete << doi.id
      else
        doi.solr = solr

        # only try to retrieve the alm data if the article exists in solr
        alm = @alm_data[doi.doi]
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

  private

  def prepare_visualization_data
    @solr_data = Hash[@report.report_dois.map do |report_doi|
      [report_doi.doi, SearchResult.from_cache(report_doi.doi)]
    end]

    dois_to_delete = manage_report_data(@report.report_dois)

    if dois_to_delete.present?
      purge_bad_dois(dois_to_delete)
      # TODO fix sort order
      manage_report_data(@report.report_dois)
    end

    if @report.has_alm?
      @draw_viz = true
    else
      @draw_viz = false
      return
    end
  end

  def single_document_visualizations
    @alm_data = AlmRequest.get_data_for_one_article(@report.report_dois)
    prepare_visualization_data

    #render single article report
    @article_usage_data = ChartData.
      generate_data_for_usage_chart(@report)

    @article_citation_data = ChartData.
      generate_data_for_citation_chart(@report)

    social_scatter_data = ChartData.
      generate_data_for_social_data_chart(@report)
    @social_scatter_header = social_scatter_data[:column_header]
    @social_scatter = social_scatter_data[:data]

    mendeley_reader_data = ChartData.
      generate_data_for_mendeley_reader_chart(@report)
    @reader_data = mendeley_reader_data[:reader_loc_data]
    @reader_total = mendeley_reader_data[:reader_total]
    render "single_document_visualizations"
  end

  def multiple_documents_visualizations
    @alm_data = AlmRequest.get_data_for_articles(@report.report_dois)
    prepare_visualization_data

    # for when a report contains many articles but very small portion of the
    # articles have alm data (without it viz page will look very weird)

    min_data_points = (ENV["MIN_DATA_POINTS"] || 2).to_i

    if @solr_data.length >= min_data_points
      bubble_data = ChartData.bubble_charts(@report)
      @article_usage_citations_age_data = bubble_data[:citation_data]
      @article_usage_mendeley_age_data = bubble_data[:mendeley_data]

      @article_usage_citation_subject_area_data = ChartData.
        subject_area_chart(@report)

      loc_data = ChartData.
        generate_data_for_articles_by_location_chart(@report)

      @total_authors_data = loc_data[:total_authors_data]
      @article_locations_data = loc_data[:locations_data]
    else
      @draw_viz = false
    end
    render "multiple_documents_visualizations"
  end

end
