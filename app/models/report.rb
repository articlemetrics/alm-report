require 'csv'

class Report < ActiveRecord::Base
  attr_accessible :user_id
  
  # TODO: figure out what we want the default sort order to be.
  # doi is likely not a good solution.
  has_many :report_dois, :order => 'sort_order'
  
  
  # Creates a child ReportDoi object for each DOI passed in in the input array.
  # Sort order is determined by the position in the array.  This object must have
  # already been saved to the DB before this method is called.
  def add_all_dois(dois)
    
    # Since reports can have many DOIs, for performance we do a batch insert.
    # Active Record won't do this on its own.
    sql = "INSERT report_dois(doi, report_id, sort_order, created_at, updated_at) VALUES "
    dois.each_with_index {|doi, i| sql << "('#{doi}', #{self.id}, #{i}, NOW(), NOW()), "}
    sql[-2] = ";"
    self.connection.execute(sql)
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

  def to_csv(options = {})

    field = options[:field]

    if (field.nil?)

      alm_data = AlmRequest.get_data_for_articles(report_dois)
      solr_data = SolrRequest.get_data_for_articles(report_dois)

      CSV.generate({ :force_quotes => true }) do | csv |
        csv << [
          "DOI", "PMID", "Title", "Authors", "Author Affiliations", "Journal", "Publication Date", "Article Type",
          "PLOS Total", "PLOS views", "PLOS PDF downloads", "PLOS XML downloads",
          "PMC Total", "PMC views", "PMC PDF Downloads",
          "CrossRef", "Scopus", "PubMed Central",
          "CiteULike", "Mendeley", "Twitter", "Facebook", "Wikipedia",
          "Research Blogging", "Nature", "Science Seeker"
        ]

        report_dois.each do | report_doi |

          article_alm_data = alm_data[report_doi.doi]
          article_data = solr_data[report_doi.doi]
          
          # If the article was unpublished (rare), skip it.
          if !article_alm_data.nil? && !article_data.nil?
  
            authors = article_data["author_display"].nil? ? "" : article_data["author_display"].join(", ")
            affiliate = article_data["affiliate"].nil? ? "" : article_data["affiliate"].join("; ")
  
            csv << [
              report_doi.doi, article_data["pmid"], article_data["title"], authors, affiliate,
              article_data["cross_published_journal_name"][0], article_data["publication_date"], article_data["article_type"],
              article_alm_data[:plos_total], article_alm_data[:plos_html], article_alm_data[:plos_pdf], article_alm_data[:plos_xml],
              article_alm_data[:pmc_total], article_alm_data[:pmc_views], article_alm_data[:pmc_pdf],
              article_alm_data[:crossref_citations], article_alm_data[:scopus_citations], article_alm_data[:pmc_citations],
              article_alm_data[:citeulike], article_alm_data[:mendeley], article_alm_data[:twitter], article_alm_data[:facebook], article_alm_data[:wikipedia],
              article_alm_data[:research_blogging], article_alm_data[:nature], article_alm_data[:scienceseeker]
            ]
          end
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
  
end
