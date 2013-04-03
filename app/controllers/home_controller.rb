require "set"

class HomeController < ApplicationController

  def index
    journals = SolrRequest.query_for_journals.collect{|x| [x, x]}

    # Add a fake entry for "all journals"
    @journals = journals.unshift([SolrRequest.ALL_JOURNALS, SolrRequest.ALL_JOURNALS])
  end

  
  def add_articles
    
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
  end
  
  
  def update_session
    
    # TODO: handle removing
    if params[:mode] != "SAVE"
      raise "Unexpected mode " + params[:mode]
    end
    
    saved = session[:dois]
    if saved.nil?
      saved = Set.new
    end
    params[:article_id].each do |doi|
      saved.add(doi)
    end
    session[:dois] = saved
    
    puts "Saved DOIs in session: #{session[:dois].to_a}"
    
    payload = {:status => "success"}
    respond_to do |format|
      format.json { render :json => payload}
    end
  end
  
end
