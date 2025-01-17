require 'csv'

class Report < ActiveRecord::Base
  has_and_belongs_to_many :users

  # TODO: figure out what we want the default sort order to be.
  # doi is likely not a good solution.
  has_many :report_dois, -> { order(:sort_order) }

  default_scope { order('created_at desc') }

  # Creates a child ReportDoi object for each DOI passed in in the input array.
  # Sort order is determined by the position in the array.  This object must have
  # already been saved to the DB before this method is called.
  def add_all_dois(dois)
    report_dois = dois.map.with_index do |doi, index|
      {
        doi: doi,
        sort_order: index
      }
    end
    self.report_dois.create(report_dois)
    # Since reports can have many DOIs, for performance we do a batch insert.
    # Active Record won't do this on its own.
    # TEMP DISABLE, PRETTY BAD.
    # sql = "INSERT report_dois(doi, report_id, sort_order, created_at, updated_at) VALUES "
    # dois.each_with_index {|doi, i| sql << "('#{doi}', #{self.id}, #{i}, NOW(), NOW()), "}
    # sql[-2] = ";"
    # self.connection.execute(sql)
  end

  # Sets the @sorted_report_dates field.
  # Precondition: load_works_from_solr has already been called.
  def sort_report_dates
    if @sorted_report_dates.nil?
      @sorted_report_dates = report_dois.collect{|report_doi| report_doi.solr.publication_date}
      @sorted_report_dates.sort!
    end
  end
  private :sort_report_dates


  # Returns the earliest publication date of any work in this report.
  # Precondition: load_works_from_solr has already been called.
  def get_earliest_report_date
    sort_report_dates
    @sorted_report_dates[0]
  end


  # Returns the latest publication date of any work in this report.
  # Precondition: load_works_from_solr has already been called.
  def get_latest_report_date
    sort_report_dates
    @sorted_report_dates[-1]
  end

  def as_json(options = {})
    alm = Alm.get_v5(report_dois.map(&:doi))

    # Ember-friendly JSON formatting
    alm["id"] = id
    alm["items"] = alm.delete("data").map do |result|
      result.update({"id" => result["doi"]})
    end

    search_results = Search.find_by_ids(alm["items"].map{ |i| i["id"] })

    alm["items"].map! do |result|
      s = search_results.find{|s| s.id == result["id"] }
      result["affiliations"] = s.affiliations
      result["journal"] = s.journal
      result["subjects"] = s.subjects.map{|k| k.gsub(/\A\/|\/\Z/, '').split(/\//)}
      result
    end

    { report: alm }
  end

  def to_csv(options = {})
    field = options[:field]

    if (field.nil?)
      alm = Alm.get_data_for_works(report_dois)

      data = report_dois.map do |report_doi|
        report_doi.solr = SearchResult.from_cache(report_doi.doi)
        report_doi.alm = alm[report_doi.doi]
      end

      CSV.generate({ :force_quotes => true }) do | csv |
        title_row = [
            "DOI", "PMID", "Publication Date", "Title", "Authors", "Author Affiliations",
            ]
        title_row += Alm::ALM_METRICS.values
        title_row += [
            "Journal", "Work Type", "Funding Statement", "Subject Areas", "Submission Date",
            "Acceptance Date", "Editors", "Work URL",
            ]
        csv << title_row

        report_dois.each do |report_doi|
          # If the work was unpublished (rare), skip it.
          row = report_doi.to_csv
          csv << row if row
        end
      end
    elsif (field == "doi")
      CSV.generate({ :force_quotes => true}) do | csv |
        csv << ["DOI"]

        report_dois.each do | report_doi |
          csv << [report_doi.doi]
        end
      end
    end
  end

  def has_alm?
    report_dois.index{|r| r.alm.present? }.present?
  end
end
