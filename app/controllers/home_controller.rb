
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

  
  def add_articles
    @tab = :select_articles
    @title = "Add Articles"
    
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
    q = SolrRequest.new(solr_params)
    @docs, @total_found = q.query
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
    
    puts "Saved DOIs in session: #{session[:dois].to_a}"
    
    payload = {:status => "success", :delta => saved.length - initial_count}
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
    
    # TODO: this performs a separate solr query to retrieve each DOI.  Probably
    # bad.  Consider alternatives: cache a doi -> doc mapping for search results?
    # Or multiple DOIs per query?
    dois.each do |doi|
      @docs << SolrRequest.get_article(doi)
    end
  end
  
end
