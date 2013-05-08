require 'csv'

class Report < ActiveRecord::Base
  attr_accessible :user_id
  
  # TODO: figure out what we want the default sort order to be.
  # doi is likely not a good solution.
  has_many :report_dois, :order => 'sort_order'
  
  
  # Creates a child ReportDoi object for each DOI passed in in the input array.
  # Sort order is determined by the position in the array.
  def add_all_dois(dois)
    dois.each_with_index {|doi, i| report_dois.create(:doi => doi, :sort_order => i)}
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
      # doi, pmid, title, journal, publication_date, authors, 
      # counter, counter_html, counter_pdf, counter_xml, 
      # pmc, pmc_html, pmc_pdf, 
      # crossref, scopus, pubmed, 
      # citeulike, mendeley, twitter, facebook, Wikipedia, 
      # researchblogging, nature, scienceseeker

      alm_data = AlmRequest.get_data_for_articles(report_dois)
      solr_data = SolrRequest.get_data_for_articles(report_dois)

      CSV.generate({ :force_quotes => true }) do | csv |
        csv << [
          "DOI", "PMID", "Title", "Journal", "Publication Date", "Authors", 
          "PLOS Total", "PLOS views", "PLOS PDF downloads", "PLOS XML downloads",
          "PMC Total", "PMC views", "PMC PDF Downloads",
          "CrossRef", "Scopus", "PubMed Central",
          "CiteULike", "Mendeley", "Twitter", "Facebook", "Wikipedia",
          "Research Blogging", "Nature", "Science Seeker"
        ]

        report_dois.each do | report_doi |

          article_alm_data = alm_data[report_doi.doi]
          article_data = solr_data[report_doi.doi]

          csv << [
            report_doi.doi, article_data["pmid"], article_data["title"], article_data["cross_published_journal_name"][0], article_data["publication_date"],
            article_data["author_display"].join(", "),
            article_alm_data[:plos_total], article_alm_data[:plos_html], article_alm_data[:plos_pdf], article_alm_data[:plos_xml],
            article_alm_data[:pmc_total], article_alm_data[:pmc_views], article_alm_data[:pmc_pdf],
            article_alm_data[:crossref_citations], article_alm_data[:scopus_citations], article_alm_data[:pmc_citations],
            article_alm_data[:citeulike], article_alm_data[:mendeley], article_alm_data[:twitter], article_alm_data[:facebook], article_alm_data[:wikipedia],
            article_alm_data[:research_blogging], article_alm_data[:nature], article_alm_data[:scienceseeker]
          ]
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
