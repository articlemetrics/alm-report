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
    @title = "Report Metrics"

    # validate dois.  remove dois that are pulled / deleted (this happens rarely)
    valid_dois = SolrRequest.validate_dois(@report.report_dois)

    current_report_dois = @report.report_dois.inject([]) { | result, report_doi | result << report_doi.doi }

    dois_to_delete = current_report_dois - valid_dois.keys

    if (!dois_to_delete.empty?)
      logger.info "Dois to delete from report #{@report.id}: #{dois_to_delete.inspect}"

      # delete the bad dois from the report
      ReportDoi.destroy_all(:report_id => @report.id, :doi => dois_to_delete)

      @report.reload

      # TODO fix sort order
    end

    # edge case where somehow the report does not have any dois after validating dois
    @show_metrics_data = true
    if @report.report_dois.length > 0
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
    else
      @show_metrics_data = false
    end
  end


  def visualizations
    load_report(params[:id])
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

    min_num_of_alm_data_points = 2

    solr_data = SolrRequest.get_data_for_articles(@report.report_dois)

    dois_to_delete = manage_report_data(@report.report_dois, solr_data, alm_data)

    if (!dois_to_delete.empty?)
      logger.info "Dois to delete from report #{@report.id}: #{dois_to_delete.inspect}"

      # delete the bad dois from the report
      ReportDoi.destroy_all(:id => dois_to_delete)
      @report.reload

      # TODO fix sort order

      manage_report_data(@report.report_dois, solr_data, alm_data)
    end

    @draw_viz = true
    if (one_article_report && @report.report_dois.length == 1)
      generate_data_for_usage_chart
      generate_data_for_citation_chart
      generate_data_for_social_data_chart
      generate_data_for_mendeley_reader_chart

      render 'visualization.html.erb'
    else
      # this covers situations where a report contains many articles but very small
      # portion of the articles have alm data  (without alm data, viz page will look very weird)
      if solr_data.length >= min_num_of_alm_data_points
        generate_data_for_bubble_charts
        generate_data_for_subject_area_chart
        generate_data_for_articles_by_location_chart
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

  # handles download data links
  def download_data
    load_report(params[:id])

    # by the time the user has clicked on a download link, the bad dois should have been removed.

    options = {}
    if (params[:field])
      options[:field] = params[:field]
    end

    respond_to do | format |
      format.csv { send_data @report.to_csv(options), :filename => "report.csv" }
    end
  end


  def generate_data_for_usage_chart
    # sort the counter data
    # ignore the gaps
    # make sure it starts on the publication date?

    counter = @report.report_dois[0].alm[:counter]
    pmc = @report.report_dois[0].alm[:pmc]

    counter_data = counter.inject({}) do | result, month_data |
      month_date = Date.new(month_data["year"].to_i, month_data["month"].to_i, 1)
      result[month_date] = month_data
      result
    end

    pmc_data = pmc.inject({}) do | result, month_data |
      month_date = Date.new(month_data["year"].to_i, month_data["month"].to_i, 1)
      result[month_date] = month_data
      result
    end

    sorted_keys = counter_data.keys.sort { | data1, data2 | data1 <=> data2 }

    @article_usage_data = []
    @article_usage_data << ["month", "Html Views", "PDF Views", "XML Views"]
    month_index = 0

    sorted_keys.each do | key |
      counter_month_data = counter_data[key]
      pmc_month_data = pmc_data[key]

      html_views = pmc_month_data.nil? ? counter_month_data["html_views"].to_i : counter_month_data["html_views"].to_i + pmc_month_data["full-text"].to_i
      pdf_views = pmc_month_data.nil? ? counter_month_data["pdf_views"].to_i : counter_month_data["pdf_views"].to_i + pmc_month_data["pdf"].to_i
      xml_views = counter_month_data["xml_views"].to_i

      @article_usage_data << [month_index, html_views, pdf_views, xml_views]
      month_index = month_index + 1
    end

  end


  def generate_data_for_citation_chart

    crossref_history_data = process_history_data(@report.report_dois[0].alm[:crossref])
    pubmed_history_data = process_history_data(@report.report_dois[0].alm[:pubmed])
    scopus_history_data = process_history_data(@report.report_dois[0].alm[:scopus])

    publication_date = Date.parse(@report.report_dois[0].alm[:publication_date])

    current_date = DateTime.now.to_date
    data_date = publication_date

    @article_citation_data = []
    @article_citation_data << ["Date", "CrossRef", "PubMed", "Scopus"]

    prev_crossref_data = 0
    prev_pubmed_data = 0
    prev_scopus_data = 0

    while (current_date > data_date) do
      key = "#{data_date.year}-#{data_date.month}"

      # it pains me to do this but smooth out the data (make sure there aren't any dips in the data)
      crossref_data = crossref_history_data[key].to_i
      pubmed_data = pubmed_history_data[key].to_i
      scopus_data = scopus_history_data[key].to_i

      crossref_data = prev_crossref_data if (crossref_data < prev_crossref_data)
      pubmed_data = prev_pubmed_data if (pubmed_data < prev_pubmed_data)
      scopus_data = prev_scopus_data if (scopus_data < prev_scopus_data)

      @article_citation_data << [key, crossref_data, pubmed_data, scopus_data]
      data_date = data_date >> 1

      prev_crossref_data = crossref_data
      prev_pubmed_data = pubmed_data
      prev_scopus_data = scopus_data
    end
  end

  def generate_data_for_social_data_chart
    citeulike = @report.report_dois[0].alm[:citeulike]

    citeulike_data = {}

    citeulike.each do | data |
      post_date = Date.parse(data["event"]["post_time"])
      key = "#{post_date.year}-#{post_date.month}"
      citeulike_data[key] = citeulike_data[key].to_i + 1
    end

    research_blogging = @report.report_dois[0].alm[:researchblogging]
    research_blogging_data = {}
    research_blogging.each do | data |
      post_date = Date.parse(data["event"]["published_date"])
      research_blogging_data["#{post_date.year}-#{post_date.month}"] = research_blogging_data["#{post_date.year}-#{post_date.month}"].to_i + 1
    end

    nature = @report.report_dois[0].alm[:nature]
    nature_data = {}
    nature.each do | data |
      post_date = Date.parse(data["event"]["published_at"])
      nature_data["#{post_date.year}-#{post_date.month}"] = nature_data["#{post_date.year}-#{post_date.month}"].to_i + 1
    end

    science_seeker = @report.report_dois[0].alm[:scienceseeker]
    science_seeker_data = {}
    science_seeker.each do | data |
      post_date = Date.parse(data["event"]["updated"])
      science_seeker_data["#{post_date.year}-#{post_date.month}"] = science_seeker_data["#{post_date.year}-#{post_date.month}"].to_i + 1
    end

    twitter = @report.report_dois[0].alm[:twitter]
    twitter_data = {}
    twitter.each do | data |
      post_date = Date.parse(data["event"]["created_at"])
      twitter_data["#{post_date.year}-#{post_date.month}"] = twitter_data["#{post_date.year}-#{post_date.month}"].to_i + 1
    end

    publication_date = Date.parse(@report.report_dois[0].alm[:publication_date])

    # SCATTER GRAPH!!
    current_date = DateTime.now.to_date
    data_date = publication_date
    month_index = 0

     @social_scatter = []

     column_header = []
     column_header << "Date"
     index = 1
     column = {}

     if (!citeulike_data.empty?)
      column_header << "Citeulike" 
      column[:citeulike] = index
      index = index + 1
     end

     if (!research_blogging_data.empty?)
      column_header << "Research Blogging" 
      column[:research_blogging] = index 
      index = index + 1
     end

     if (!nature_data.empty?)
      column_header << "Nature" 
      column[:nature] = index 
      index = index + 1
     end

     if (!science_seeker_data.empty?)
      column_header << "Science Seeker" 
      column[:science_seeker] = index 
      index = index + 1
     end

     if (!twitter_data.empty?)
      column_header << "Twitter" 
      column[:twitter] = index 
      index = index + 1
     end
         
     @social_scatter << column_header

    while (current_date > data_date) do
      key = "#{data_date.year}-#{data_date.month}"

      if (!citeulike_data[key].nil?)
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:citeulike]] = citeulike_data[key].to_i
        @social_scatter << row
      else
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:citeulike]] = -5
        @social_scatter << row        
      end

      if (!research_blogging_data[key].nil?)
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:research_blogging]] = research_blogging_data[key].to_i
        @social_scatter << row
      else
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:research_blogging]] = -5
        @social_scatter << row        
      end

      if (!nature_data[key].nil?)
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:nature]] = nature_data[key].to_i
        @social_scatter << row
           
      end

      if (!science_seeker_data[key].nil?)
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:science_seeker]] = science_seeker_data[key].to_i
        @social_scatter << row
      end

      if (!twitter_data[key].nil?)
        row = Array.new(column_header.size)
        row[0] = month_index
        row[column[:twitter]] = twitter_data[key].to_i
        @social_scatter << row
      end
      
      month_index = month_index + 1
      data_date = data_date >> 1
    end

@social_scatter_d3 = []
    current_date = DateTime.now.to_date
    data_date = publication_date
    month_index = 0

    while (current_date > data_date) do
      key = "#{data_date.year}-#{data_date.month}"

      @social_scatter_d3 << [month_index, citeulike_data[key].to_i, "CiteULike"]
@social_scatter_d3 << [month_index, research_blogging_data[key].to_i, "Research Blogging"]
        @social_scatter_d3 << [month_index, nature_data[key].to_i, "Nature"]
        @social_scatter_d3 << [month_index, science_seeker_data[key].to_i, "Science Seeker"]
@social_scatter_d3 << [month_index, twitter_data[key].to_i, "Twitter"]

      # if (!citeulike_data[key].nil?)
      #   @social_scatter_d3 << [month_index, citeulike_data[key].to_i, "citeulike"]
      # end

      # if (!research_blogging_data[key].nil?)
      #   @social_scatter_d3 << [month_index, research_blogging_data[key].to_i, "research_blogging"]
      # end

      # if (!nature_data[key].nil?)
      #   @social_scatter_d3 << [month_index, nature_data[key].to_i, "nature_data"]
      # end

      # if (!science_seeker_data[key].nil?)
      #   @social_scatter_d3 << [month_index, science_seeker_data[key].to_i, "science_seeker_data"]
      # end

      # if (!twitter_data[key].nil?)
      #   @social_scatter_d3 << [month_index, twitter_data[key].to_i, "twitter_data"]
      # end
      
      month_index = month_index + 1
      data_date = data_date >> 1
    end

  end

  def generate_data_for_mendeley_reader_chart
    mendeley = @report.report_dois[0].alm[:mendeley]

puts "!!!!!!!!!MENDELEY #{mendeley.inspect}"
    reader_country = mendeley["stats"]["country"]


    @reader_data = []
    @reader_data << ["Country", "Readers"]

    reader_country.each do | data |
      @reader_data << [data["name"], data["value"]]
    end

  end

  def process_history_data(history_data)

    monthly_historical_data = {}

    # sort
    history_data.sort! { | data1, data2 | Date.parse(data1["update_date"]) <=> Date.parse(data2["update_date"]) }

    data = history_data[0]
    if (!data.nil?)
      data_date = Date.parse(data["update_date"])
      monthly_historical_data["#{data_date.year}-#{data_date.month}"] = data["total"]

      current_date = data_date

      history_data.each do | data |
        data_date = Date.parse(data["update_date"])

        if (current_date.year == data_date.year)
          if (current_date.month == data_date.month)

          elsif (current_date.month < data_date.month)
            current_date = data_date
            monthly_historical_data["#{data_date.year}-#{data_date.month}"] = data["total"]
          end
        elsif (current_date.year < data_date.year)
          current_date = data_date
          monthly_historical_data["#{data_date.year}-#{data_date.month}"] = data["total"]
        end
      end
    end

    return monthly_historical_data;
  end

end
