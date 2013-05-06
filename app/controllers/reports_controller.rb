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
    saved_dois = {}
    @report.report_dois.each do |report_doi|
      saved_dois[report_doi.doi] = report_doi.sort_order
    end
    session[:dois] = saved_dois
  end
  
  
  def metrics
    load_report(params[:id])
    @report_sub_tab = :metrics
    @title = "Sample Metrics"
    
    # validate dois.  remove dois that are pulled / deleted (this happens rarely)
    valid_dois = SolrRequest.validate_dois(@report.report_dois)

    current_report_dois = @report.report_dois.inject([]) { | result, report_doi | result << report_doi.doi }

    dois_to_delete = current_report_dois - valid_dois.keys
    
    logger.info "Dois to delete from report #{@report.id}: #{dois_to_delete.inspect}"

    if (!dois_to_delete.empty?)

      # delete the bad dois from the report
      ReportDoi.destroy_all(:report_id => @report.id, :doi => dois_to_delete)

      @report.reload

      # TODO fix sort order
    end

    @total_found = @report.report_dois.length

    results_per_page = 5
    set_paging_vars(params[:current_page], results_per_page)
    
    # Create a new array for display that is only the articles on the current page,
    # to limit what we have to load from solr and ALM.
    @dois = @report.report_dois[(@start_result) - 1..(@end_result - 1)]
    i = @start_result

    alm_data = AlmRequest.get_data_for_articles(@dois)
    solr_data = SolrRequest.get_data_for_articles(@dois)

    manage_report_data(@dois, solr_data, alm_data, i)
  end


  def visualizations
    load_report(params[:id])
    @report_sub_tab = :visualizations
    @title = "Report Visualizations"

    alm_data = AlmRequest.get_data_for_viz(@report.report_dois)
    solr_data = SolrRequest.get_data_for_articles(@report.report_dois)

    dois_to_delete = manage_report_data(@report.report_dois, solr_data, alm_data)

    if (!dois_to_delete.empty?)

      # delete the bad dois from the report
      ReportDoi.destroy_all(:id => dois_to_delete)
      @report.reload
      manage_report_data(@report.report_dois, solr_data, alm_data)
    end

    generate_data_for_bubble_charts
    generate_data_for_subject_area_chart
    generate_data_for_articles_by_location_chart
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


  # Populates @article_usage_citations_age_data and @article_usage_mendeley_age_data, used from
  # javascript to generate the bubble charts.
  def generate_data_for_bubble_charts
    @article_usage_citations_age_data = []
    @article_usage_mendeley_age_data = []
    @article_usage_citations_age_data << ["Title", "Months", "Total Usage", "Journal", "Scopus"]
    @article_usage_mendeley_age_data << ["Title", "Months", "Total Usage", "Journal", "Mendeley"]
    @report.report_dois.each do |report_doi|
      if (!report_doi.alm.nil?)
        days = (Date.today - report_doi.solr["publication_date"]).to_i
        months = days / 30

        usage = report_doi.alm[:total_usage]
        @article_usage_citations_age_data << [report_doi.solr["title"], months, usage,
            report_doi.solr["cross_published_journal_name"][0], report_doi.alm[:scopus_citations]]
        @article_usage_mendeley_age_data << [report_doi.solr["title"], months, usage,
            report_doi.solr["cross_published_journal_name"][0], report_doi.alm[:mendeley]]
      end
    end
  end

  def generate_data_for_subject_area_chart
    @article_usage_citation_subject_area_data = []
    
    placeholder_subject = 'subject'

    @article_usage_citation_subject_area_data << ['Subject Area', '', '# of articles', 'Total Usage']
    @article_usage_citation_subject_area_data << [placeholder_subject, '', 0, 0]

    subject_area_data = {}

    @report.report_dois.each do | report_doi |
      # get the subject area 
      if !report_doi.solr["subject"].nil?
        # collect the second level subject areas
        # we are looking for unique list of second level subject areas
        # (if they have different parent (different 1st level subject area term),
        #  we are treating them as the same thing)
        report_doi.solr["subject"].each do | subject_area_full |
          subject_areas = subject_area_full.split('/')
          subject_area = subject_areas[2]
          if !subject_area.nil?
            if subject_area_data[subject_area].nil?
              subject_area_data[subject_area] = []
            end
            # associate article to the subject area
            subject_area_data[subject_area] << report_doi
          end
        end
      end
    end

    # loop through subjects
    subject_area_data.each do | subject_area, report_dois |
      total_usage = report_dois.inject(0) { | sum, report_doi | sum + report_doi.alm[:total_usage] if (!report_doi.alm.nil?) }
      if (!total_usage.nil?)
        @article_usage_citation_subject_area_data << [subject_area, placeholder_subject, report_dois.size, total_usage]
      end
    end
  end

  def generate_data_for_articles_by_location_chart
    @total_authors_data = 0
    @article_locations_data = []

    @report.report_dois.each do | report_doi |
      solr_data = report_doi.solr

      if (!solr_data["author_display"].nil?)
        @total_authors_data = @total_authors_data + solr_data["author_display"].length
      end

      if (!solr_data["affiliate"].nil?)
        solr_data["affiliate"].each do | affiliate |
          aff_data = affiliate.split(",")
          aff_data.map { |location| location.strip! }
          if aff_data.length >= 3
            @article_locations_data << [aff_data[-2, 2].join(", "), 1]
          end
        end
      end
    end
    # get a unique list of locations
    @article_locations_data.uniq!

    # sizeAxis is a hack to make the marker smaller
    @article_locations_data.unshift(["locations", "size"])

    # TODO translate the location information to lat and lng
    # https://developers.google.com/maps/documentation/geocoding/
    # the reason why the graph is slow is the graph is translating the location information
    # to lat and long
  end
  
end
