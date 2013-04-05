require "set"

# TODO: separate out the methods into multiple Controller classes, if necessary.
# Right now this is the entire app.
class HomeController < ApplicationController

  def index
    @tab = :select_articles
    journals = SolrRequest.query_for_journals.collect{|x| [x, x]}

    # Add a fake entry for "all journals"
    @journals = journals.unshift([SolrRequest.ALL_JOURNALS, SolrRequest.ALL_JOURNALS])
  end
  
  
  # Sets fields used by the UI for results paging of articles.
  # A precondition of this method is that @total_found is set appropriately.
  def set_paging_vars(current_page)
    current_page = current_page.nil? ? "1" : current_page
    @start_result = (current_page.to_i - 1) * $RESULTS_PER_PAGE + 1
    @end_result = @start_result + $RESULTS_PER_PAGE - 1
    @end_result = [@end_result, @total_found].min
  end
  private :set_paging_vars

  
  def add_articles
    @tab = :select_articles
    
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
  
  
  def update_session
    saved = session[:dois]
    if saved.nil?
      saved = Set.new
    end
    initial_count = saved.length
    if params[:mode] == "SAVE"
      
      # TODO: enforce a limit on the number of articles users can save to
      # their session.  (500?)

      params[:article_ids].each {|doi| saved.add(doi)}
    elsif params[:mode] == "REMOVE"
      params[:article_ids].each {|doi| saved.delete(doi)}
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
  
  
  def clear_session
    
    puts "Clearing session DOIs..."
    
    session[:dois] = Set.new
    head :no_content
  end
  
  
  def preview_list
    @tab = :preview_list
    dois = session[:dois].nil? ? Set.new : session[:dois]
    @total_found = dois.length
    set_paging_vars(params[:current_page])
      
    # TODO: sort in a better way than alphabetically by DOI?
    dois = dois.to_a.sort
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
