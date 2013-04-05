class ApplicationController < ActionController::Base

  protect_from_forgery
  
  before_filter :set_preview_list_count

  # Sets the number of DOIs saved in the session as an instance field;
  # used across several pages.
  def set_preview_list_count
    saved_dois = session[:dois]
    @preview_list_count = saved_dois.nil? ? 0 : saved_dois.length
  end
  
end
