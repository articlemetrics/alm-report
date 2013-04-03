require "set"

# Controller class that handles adding and removing DOIs from the in-memory session.
class SessionController < ApplicationController

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
