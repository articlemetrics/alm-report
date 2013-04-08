class ApplicationController < ActionController::Base

  protect_from_forgery
  
  before_filter :set_preview_list_count

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
  
end
