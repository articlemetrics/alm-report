
# TODO: separate out the methods into multiple Controller classes, if necessary.
# Right now this is the entire app except for the report page.
class HomeController < ApplicationController


  def index
    @tab = :select_articles
    @title = "Homepage"
    journals = SolrRequest.query_for_journals.collect{|x| [x, x]}

    # Add a fake entry for "all journals"
    @journals = journals.unshift([SolrRequest.ALL_JOURNALS, SolrRequest.ALL_JOURNALS])
  end
  
  
  # Performs a solr search based on the parameters passed into an action.
  # Returns a tuple of (solr documents, total results found).  The length
  # of the solr documents will be limited by the page size, while the total
  # results found will not.
  def search_from_params(page_size=$RESULTS_PER_PAGE)

    # Strip out form params not relevant to solr.
    solr_params = {}
    params.keys.each do |key|
      if !["utf8", "commit", "controller", "action"].include?(key.to_s)
        solr_params[key.to_sym] = params[key]
      end
    end
    @start_date, @end_date = SolrRequest.parse_date_range(solr_params.delete(:publication_days_ago),
        solr_params.delete(:datepicker1), solr_params.delete(:datepicker2))
    date_range = SolrRequest.build_date_range(@start_date, @end_date)
    if !date_range.nil?
      solr_params[:publication_date] = date_range
    end
    q = SolrRequest.new(solr_params, page_size)
    q.query
  end
  private :search_from_params

  
  def add_articles
    @tab = :select_articles
    @title = "Add Articles"
    @docs, @total_found = search_from_params
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
    saved = session[:dois]
    if saved.nil?
      saved = {}
    end
    initial_count = saved.length
    if params[:mode] == "SAVE"
      
      # TODO: enforce a limit on the number of articles users can save to
      # their session.  (500?)

      params[:article_ids].each do |doc_key|
        doi, pub_date = parse_article_key(doc_key)
        saved[doi] = pub_date
      end
    elsif params[:mode] == "REMOVE"
      params[:article_ids].each do |doc_key|
        doi, _ = parse_article_key(doc_key)
        saved.delete(doi)
      end
    else
      raise "Unexpected mode " + params[:mode]
    end
    session[:dois] = saved

    payload = {:status => "success", :delta => saved.length - initial_count}
    respond_to do |format|
      format.json { render :json => payload}
    end
  end
  
  
  # Ajax action that handles the "Select all nnn articles" link.  Selects
  # *all* of the articles from the search, not just those on the current page.
  # (Subject to the article limit.)
  def select_all_search_results
    
    # Just in case the user is not on the first page, we always want to start saving
    # from the first.
    params[:current_page] = "1"
    saved = session[:dois]
    if saved.nil?
      saved = {}
    end
    initial_count = saved.length

    # For efficiency, only load as many articles as can be stored in the session.
    # TODO: correct messaging of this to the user.
    docs, total_found = search_from_params($ARTICLE_LIMIT)
    docs.each {|doc| saved[doc["id"]] = doc["publication_date"].strftime("%s").to_i}
    session[:dois] = saved
    payload = {:status => "error", :delta => saved.length - initial_count}
    respond_to do |format|
      format.json { render :json => payload}
    end
  end
  

  # Action that clears any DOIs in the session and redirects to home.
  def start_over
    session[:dois] = {}
    redirect_to :action => :index
  end
  
  
  def preview_list
    @tab = :preview_list
    @title = "Preview List"
    dois = session[:dois].nil? ? {} : session[:dois]
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
  
end
