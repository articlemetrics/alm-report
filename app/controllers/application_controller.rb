class ApplicationController < ActionController::Base

  protect_from_forgery
  
  before_filter :set_preview_list_count
  before_filter :display_nav

  # Sets the number of DOIs saved in the session as an instance field;
  # used across several pages.
  def set_preview_list_count
    saved_dois = session[:dois]
    @preview_list_count = saved_dois.nil? ? 0 : saved_dois.length
  end
  
  
  # Sets fields used by the UI for results paging of articles.
  # A precondition of this method is that @total_found is set appropriately.
  def set_paging_vars(current_page, results_per_page=$RESULTS_PER_PAGE)
    current_page = current_page.nil? ? "1" : current_page
    @start_result = (current_page.to_i - 1) * results_per_page + 1
    @end_result = @start_result + results_per_page - 1
    @end_result = [@end_result, @total_found].min
  end
  protected :set_paging_vars
  
  # The navigation UI element (1 Select Articles and etc) will not be displayed on the static pages
  # That is the only change for the static pages so having a whole separate layout seemed like an overkill
  # This might change in the future
  def display_nav
    @display_nav = true
  end

end
