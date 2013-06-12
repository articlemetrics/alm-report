
require "set"

module ChartData

  # Populates @article_usage_citations_age_data and @article_usage_mendeley_age_data, used from
  # javascript to generate the bubble charts.
  def self.generate_data_for_bubble_charts(report)
    article_usage_citations_age_data = []
    article_usage_mendeley_age_data = []
    article_usage_citations_age_data << ["Title", "Months", "Total Usage", "Journal", "Scopus"]
    article_usage_mendeley_age_data << ["Title", "Months", "Total Usage", "Journal", "Mendeley"]
    report.report_dois.each do |report_doi|
      if (!report_doi.alm.nil?)
        days = (Date.today - report_doi.solr["publication_date"]).to_i
        months = days / 30

        usage = report_doi.alm[:total_usage]
        article_usage_citations_age_data << [report_doi.solr["title"], months, usage,
            report_doi.solr["cross_published_journal_name"][0], report_doi.alm[:scopus_citations]]
        article_usage_mendeley_age_data << [report_doi.solr["title"], months, usage,
            report_doi.solr["cross_published_journal_name"][0], report_doi.alm[:mendeley]]
      end
    end

    return {:citation_data => article_usage_citations_age_data, :mendeley_data => article_usage_mendeley_age_data}
  end

  # generate data for subject area treemap graph
  def self.generate_data_for_subject_area_chart(report)
    article_usage_citation_subject_area_data = []

    placeholder_subject = 'subject'

    article_usage_citation_subject_area_data << ['Subject Area', '', '# of articles', 'Total Usage']
    article_usage_citation_subject_area_data << [placeholder_subject, '', 0, 0]

    subject_area_data = {}

    report.report_dois.each do | report_doi |
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
        article_usage_citation_subject_area_data << [subject_area, placeholder_subject, report_dois.size, total_usage]
      end
    end

    return article_usage_citation_subject_area_data
  end

  
  # Generates tooltip text for markers on the article locations chart,
  # based on the author affiliations.  Returns a tuple of the first
  # and second lines of the tooltip.  (Unfortunately, it seems impossible
  # to have more than two lines of tooltip text when using the
  # google.visualization.GeoChart.)
  #
  # TODO: show author names in the tooltip.  This is not possible with our
  # current solr schema, since we just have flat lists of authors, and
  # author affiliations, and no linkage between them.  (In the article XML
  # they are linked.)
  def self.generate_location_tooltip(address, author_count, institutions)
    line1 = "#{address}: #{author_count} author"
    if author_count > 1
      line1 += "s"
    end
    if institutions.length == 1
      line2 = institutions[0]
    else
      line2 = "#{institutions.length} institutions"
    end
    return [line1, line2]
  end
  
  # Generate data for author location geo graph 
  def self.generate_data_for_articles_by_location_chart(report)
    total_authors_data = 0
    
    # Map from address to author count and list of author institutions, parsed
    # from the author affiliate data.
    address_to_count_and_inst = Hash.new{|h, k| h[k] = [0, []]}

    report.report_dois.each do | report_doi |
      solr_data = report_doi.solr

      if (!solr_data["author_display"].nil?)
        total_authors_data = total_authors_data + solr_data["author_display"].length
      end

      if (!solr_data["affiliate"].nil?)
        solr_data["affiliate"].each do | affiliate |
          fields = GeocodeRequest.parse_location_from_affiliate(affiliate)
          if !fields.nil?
            count, institutions = address_to_count_and_inst[fields[0]]
            count += 1
            institutions << fields[1]
            address_to_count_and_inst[fields[0]] = [count, institutions]
          end
        end
      end
    end
    found_in_db, not_found = Geocode.load_from_addresses(address_to_count_and_inst.keys)
    Rails.logger.info("Found #{found_in_db.length} locations in geocodes table, out of #{address_to_count_and_inst.length} total")

    # Rendering the map with pre-geocoded info is by far the fastest option.
    # Otherwise, we send the map data consisting of addresses, which the chart
    # javascript will sequentially geocode, *slowly*.  However, it's not
    # feasible to geocode locations here at request time--see comments in
    # geocode_request.rb.  Also, the map chart won't accept data that's a mix
    # of address and lat/lng.  So we use the fast way if we have coordinates
    # for "most" of the locations, and there are no more than a few ungeocoded
    # locations.  (The geocodes table now has over 300k cities, and in my
    # experience ones that aren't found there are usually typos.)
    fraction = found_in_db.length.to_f / address_to_count_and_inst.length.to_f
    if fraction > APP_CONFIG["min_fraction_of_locations_to_use_geocodes"] \
        && address_to_count_and_inst.length - found_in_db.length <= APP_CONFIG["max_unfound_locations_to_use_geocodes"]
      article_locations_data = []
      address_to_count_and_inst.each do |address, fields|
        count = fields[0]
        institutions = fields[1]
        geo = found_in_db[address]
        if !geo.nil?

          # Relative size of the marker on the map.  It's nice to have this be a function
          # of the number of authors in that location, but I've found that if we use
          # a linear scale, the large markers tend to take over the map.  So after
          # playing around a while I settled on the following concave function.
          size = Math.atan(Math.log2(count + 1))
          
          # There's an undocumented feature of the GeoChart where you can specify
          # the first line of tooltip text as an element right after the lat/lng.
          # Otherwise, the first line will be lat/lng.  The final element is the
          # second line.  See
          # https://groups.google.com/forum/#!msg/google-visualization-api/U6qOYwjcd-Q/NoGcmqsC_VsJ
          tooltip = generate_location_tooltip(address, count, institutions)
          article_locations_data << [geo.latitude, geo.longitude, tooltip[0], size, size, tooltip[1]]
        end
      end
    else
      Rails.logger.warn("Not using geocoded lat/long because we couldn't find enough locations in the DB")
      not_found.each {|i| Rails.logger.warn("Not found: #{i}")}
      article_locations_data = []
      address_to_count_and_inst.each do |address, fields|
        count = fields[0]
        institutions = fields[1]
        size = Math.atan(Math.log2(count + 1))
        tooltip = generate_location_tooltip(address, count, institutions)
        
        # When we're not in lat/lng mode, the first line of the tooltip must
        # be the address.
        article_locations_data << [address, size, size, tooltip[1]]
      end
    end
    return {:total_authors_data => total_authors_data, :locations_data => article_locations_data}
  end


  # Generate data for single article usage chart 
  def self.generate_data_for_usage_chart(report)

    # get counter and pmc usage stat data
    counter = report.report_dois[0].alm[:counter]
    pmc = report.report_dois[0].alm[:pmc]

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

    # sort the keys by date (using counter data)
    sorted_keys = counter_data.keys.sort { | data1, data2 | data1 <=> data2 }

    article_usage_data = []

    month_index = 0

    # process the usage data in order 
    # ignore gaps 
    sorted_keys.each do | key |
      counter_month_data = counter_data[key]
      pmc_month_data = pmc_data[key]

      html_views = pmc_month_data.nil? ? counter_month_data["html_views"].to_i : counter_month_data["html_views"].to_i + pmc_month_data["full-text"].to_i
      pdf_views = pmc_month_data.nil? ? counter_month_data["pdf_views"].to_i : counter_month_data["pdf_views"].to_i + pmc_month_data["pdf"].to_i
      xml_views = counter_month_data["xml_views"].to_i

      article_usage_data << [month_index,
        html_views, "Month: #{month_index}\nHtml Views: #{html_views}",
        pdf_views, "Month: #{month_index}\nPDF Views: #{pdf_views}",
        xml_views, "Month: #{month_index}\nXML Views: #{xml_views}"]

      month_index = month_index + 1
    end

    return article_usage_data

  end

  # generate data for single article citation chart
  def self.generate_data_for_citation_chart(report)

    crossref_history_data = process_history_data(report.report_dois[0].alm[:crossref])
    pubmed_history_data = process_history_data(report.report_dois[0].alm[:pubmed])
    scopus_history_data = process_history_data(report.report_dois[0].alm[:scopus])

    # starting date is the publication date
    data_date = Date.parse(report.report_dois[0].alm[:publication_date])
    current_date = DateTime.now.to_date

    article_citation_data = []

    prev_crossref_data = 0
    prev_pubmed_data = 0
    prev_scopus_data = 0

    month_index = 0

    while (current_date > data_date) do
      key = "#{data_date.year}-#{data_date.month}"

      # it pains me to do this but smooth out the data (make sure there aren't any dips in the data)
      crossref_data = crossref_history_data[key].to_i
      pubmed_data = pubmed_history_data[key].to_i
      scopus_data = scopus_history_data[key].to_i

      crossref_data = prev_crossref_data if (crossref_data < prev_crossref_data)
      pubmed_data = prev_pubmed_data if (pubmed_data < prev_pubmed_data)
      scopus_data = prev_scopus_data if (scopus_data < prev_scopus_data)

      article_citation_data << [month_index,
        crossref_data, "Month: #{month_index}\nCrossRef: #{crossref_data}",
        pubmed_data, "Month: #{month_index}\nPubMed: #{pubmed_data}",
        scopus_data, "Month: #{month_index}\nScopus: #{scopus_data}"]

      data_date = data_date >> 1
      month_index = month_index + 1

      prev_crossref_data = crossref_data
      prev_pubmed_data = pubmed_data
      prev_scopus_data = scopus_data
    end

    return article_citation_data
  end

  # Generate data for single article social media chart
  def self.generate_data_for_social_data_chart(report)

    social_data = []

    citeulike = report.report_dois[0].alm[:citeulike]
    citeulike_data = process_social_data(citeulike, "post_time")
    social_data << {:data => citeulike_data, :column_name => "CiteULike", :column_key => "citeulike"}

    research_blogging = report.report_dois[0].alm[:researchblogging]
    research_blogging_data = process_social_data(research_blogging, "published_date")
    social_data << {:data => research_blogging_data, :column_name => "Research Blogging", :column_key => "research_blogging"}

    nature = report.report_dois[0].alm[:nature]
    nature_data = process_social_data(nature, "published_at")
    social_data << {:data => nature_data, :column_name => "Nature", :column_key => "nature"}

    science_seeker = report.report_dois[0].alm[:scienceseeker]
    science_seeker_data = process_social_data(science_seeker, "updated")
    social_data << {:data => science_seeker_data, :column_name => "Science Seeker", :column_key => "science_seeker"}

    twitter = report.report_dois[0].alm[:twitter]
    twitter_data = process_social_data(twitter, "created_at")
    social_data << {:data => twitter_data, :column_name => "Twitter", :column_key => "twitter"}

    # start at article publication date
    data_date = Date.parse(report.report_dois[0].alm[:publication_date])
    current_date = DateTime.now.to_date

    social_scatter = []

    column_header = []
    index = 1
    column = {}

    social_data.each do | data | 
      if (!data[:data].empty?)
        # collect the sources that will be used for the graph (ones with data)
        column_header << data[:column_name]

        # keep track of the column index
        column[data[:column_key]] = index
        # + 2 because each column will have tooltip column to go with it
        index = index + 2
      end
    end

    month_index = 0

    # make sure the row has the correct number of columns
    # * 2 => each source column has a tooltip column to go with it
    # + 1 => month column (the first column)
    num_of_cols = (column_header.size * 2) + 1

    while (current_date > data_date) do
      key = "#{data_date.year}-#{data_date.month}"

      social_data.each do | data |
        month_data = data[:data][key]
        # check to see if there is data for the given month for the given source
        if (!month_data.nil?)
          row = Array.new(num_of_cols)
          row[0] = month_index

          # use the correct column index of the given source
          col_index = column[data[:column_key]]
          row[col_index] = month_data.to_i
          row[col_index + 1] = "Month: #{month_index}\n#{data[:column_name]}: #{month_data.to_i}"

          social_scatter << row
        end
      end
      
      month_index = month_index + 1
      data_date = data_date >> 1
    end

    return {:column_header => column_header, :data => social_scatter}
  end


  def self.process_social_data(raw_social_data, date_key)
    social_data = {}

    raw_social_data.each do | data |
      post_date = Date.parse(data["event"][date_key])
      key = "#{post_date.year}-#{post_date.month}"
      social_data[key] = social_data[key].to_i + 1
    end

    return social_data
  end


  # Gather Mendeley reader information for geo chart
  def self.generate_data_for_mendeley_reader_chart(report)
    mendeley = report.report_dois[0].alm[:mendeley]

    reader_total = mendeley["stats"]["readers"].to_i

    reader_country = mendeley["stats"]["country"]

    reader_data = []
    reader_data << ["Country", "Readers"]

    reader_country.each do | data |
      reader_data << [data["name"], data["value"]]
    end

    return {:reader_total => reader_total, :reader_loc_data => reader_data}
  end


  def self.process_history_data(history_data)

    monthly_historical_data = {}

    # sort the history data
    history_data.sort! { | data1, data2 | Date.parse(data1["update_date"]) <=> Date.parse(data2["update_date"]) }

    # grab the first entry in the array of historical data
    data = history_data[0]

    if (!data.nil?)
      data_date = Date.parse(data["update_date"])
      key = "#{data_date.year}-#{data_date.month}"
      monthly_historical_data[key] = data["total"]

      current_date = data_date

      # loop through the historical data and pick out one data point per month 
      # want to grab the first data retrieval event
      # alm usually retrieves data more than once a month
      history_data.each do | data |
        data_date = Date.parse(data["update_date"])
        key = "#{data_date.year}-#{data_date.month}"

        if (current_date.year == data_date.year)
          if (current_date.month == data_date.month)
            # ignore all the other data retrieval events that occured in the given month
          elsif (current_date.month < data_date.month)
            current_date = data_date
            monthly_historical_data[key] = data["total"]
          end
        elsif (current_date.year < data_date.year)
          current_date = data_date
          monthly_historical_data[key] = data["total"]
        end
      end
    end

    return monthly_historical_data;
  end


end