
# TODO: separate out the methods into multiple Controller classes, if necessary.
# Right now this is the entire app except for the report page.
class HomeController < ApplicationController


  def index
    @tab = :select_articles
    @title = "Homepage"

    journals = SolrRequest.get_journal_name_key
    journals.collect! { | journal | [journal[:journal_name], journal[:journal_name]] }

    # Add a fake entry for "all journals"
    @journals = journals.unshift([SolrRequest.ALL_JOURNALS, SolrRequest.ALL_JOURNALS])
  end
  
  
  # Performs a solr search based on the parameters passed into an action.
  # Returns a tuple of (solr documents, total results found).  If argument fl
  # is none-nil, it specifies what results fields we want to retrieve from solr.
  def search_from_params(fl=nil)

    # Strip out form params not relevant to solr.
    solr_params = {}
    params.keys.each do |key|
      if !["utf8", "commit", "controller", "action"].include?(key.to_s)
        solr_params[key.to_sym] = params[key]
      end
    end

    if (solr_params[:publication_days_ago].nil?)
      # default value
      solr_params[:publication_days_ago] = -1
    end

    @start_date, @end_date = SolrRequest.parse_date_range(solr_params.delete(:publication_days_ago),
        solr_params.delete(:datepicker1), solr_params.delete(:datepicker2))
    date_range = SolrRequest.build_date_range(@start_date, @end_date)
    if !date_range.nil?
      solr_params[:publication_date] = date_range
    end
    q = SolrRequest.new(solr_params, fl)
    q.query
  end
  private :search_from_params

  
  def add_articles
    @tab = :select_articles
    @title = "Add Articles"

    @docs, @total_found = search_from_params

    if !params["unformattedQueryId"].nil?
      # search exected from the advanced search page
      # convert the journal key to journal name
      @filter_journal_names = []
      if !params["filterJournals"].nil?
        if (!APP_CONFIG["journals"].nil? && APP_CONFIG["journals"].size > 0)
          params["filterJournals"].each do | journal_key |
            journal_name = APP_CONFIG["journals"][journal_key]
            if !journal_name.nil?
              @filter_journal_names << journal_name
            end
          end
        end
      end

    end

    # get the dois that have been selected
    dois = session[:dois]


    # make sure that the articles that have been checked previously are checked when we render the page
    if (!dois.nil? && !dois.empty?)
      @docs.each do | doc |
        if (dois.has_key?(doc["id"]))
          doc[:doc_checked] = true
        end
      end
    end

    set_paging_vars(params[:current_page])
  end
  
  
  # Parses date sent in the ajax call to update_session.  This is of the form
  # "10.1371/journal.pone.0052192|12345678"; that is, a DOI and a timestamp separated by
  # a '|' character.  Returns (doi, timestamp).
  def parse_article_key(key)
    fields = key.split("|")
    return fields[0], fields[1].to_i
  end
  private :parse_article_key
  
  
  def update_session
    initial_count = @saved_dois.length
    status = "success"
    if params[:mode] == "SAVE"
      if initial_count >= APP_CONFIG["article_limit"]
        status = "limit"
      else
        params[:article_ids][0..(APP_CONFIG["article_limit"] - initial_count - 1)].each do |doc_key|
          doi, pub_date = parse_article_key(doc_key)
          @saved_dois[doi] = pub_date
        end
      end
    elsif params[:mode] == "REMOVE"
      params[:article_ids].each do |doc_key|
        doi, _ = parse_article_key(doc_key)
        @saved_dois.delete(doi)
      end
    else
      raise "Unexpected mode " + params[:mode]
    end

    payload = {:status => status, :delta => @saved_dois.length - initial_count}
    respond_to do |format|
      format.json { render :json => payload}
    end
  end
  
  
  # Simple AJAX action that returns the count of articles stored in the session.
  def get_article_count
    respond_to do |format|
      format.json {render :json => @saved_dois.length}
    end
  end
  
  
  # Queries solr for the results used by select_all_search_results.
  def get_all_results
    page = params.delete(:current_page)
      
    # For efficiency, we want to query solr for the smallest number of results.
    # However, this is difficult because the user may have already selected
    # some articles from various pages of the search results, and there is no
    # easy way to determine the intersection of this with the search we're about
    # to do.  Using article_limit * 2 as our requested number of results handles
    # various pathological cases such as the user having checked every other
    # search result.
    limit = APP_CONFIG["article_limit"] * 2
    
    # solr usually returns 500s if you try to retreive all 1000 articles at once,
    # so we do paging here (with a larger page size than in the UI).
    params[:start] = 1
    page_size = 200
    results = []
    begin
      rows = [page_size, limit - params[:start] + 1].min
      params[:rows] = rows
      docs, _ = search_from_params("id,publication_date")
      results += docs
      params[:start] = params[:start] + rows
    end while params[:start] <= limit
    results
  end
  private :get_all_results
  
  
  # Ajax action that handles the "Select all nnn articles" link.  Selects
  # *all* of the articles from the search, not just those on the current page.
  # (Subject to the article limit.)
  def select_all_search_results
    initial_count = @saved_dois.length

    # This is a little weird... if the user has no more capacity before the
    # article limit, return an error status, but if at least one article can
    # be added, return success.
    if initial_count >= APP_CONFIG["article_limit"]
      status = "limit"
    else
      status = "success"
      begin
        docs = get_all_results
      rescue SolrError
        logger.warn("Error querying solr: #{$!}")
        
        # Send a json response, instead of the rails 500 HTML page.
        respond_to do |format|
          format.json {render :json => {:status => "error"}, :status => 500}
        end
        return
      end
      docs.each do |doc|
        begin
          @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i
        rescue DoiLimitReachedError
          break
        end
      end
    end

    payload = {:status => status, :delta => @saved_dois.length - initial_count}
    respond_to do |format|
      format.json { render :json => payload}
    end
  end
  

  # Action that clears any DOIs in the session and redirects to home.
  def start_over
    @saved_dois.clear
    redirect_to :action => :index
  end
  
  
  def preview_list
    @tab = :preview_list
    @title = "Preview List"
    dois = @saved_dois.clone
    @total_found = dois.length
    set_paging_vars(params[:current_page])
    
    # Convert to array, sorted in descending order by timestamp, then throw away the timestamps.
    dois = dois.sort_by{|doi, timestamp| -timestamp}.collect{|x| x[0]}
    dois = dois[(@start_result) - 1..(@end_result - 1)]
    @docs = []
    
    solr_data = SolrRequest.get_data_for_articles(dois)
    dois.each do |doi|
      @docs << solr_data[doi]
    end
  end


  def advanced
    @tab = :select_articles
    @title = "Advanced Search"

    @journals = SolrRequest.get_journal_name_key
  end
end
