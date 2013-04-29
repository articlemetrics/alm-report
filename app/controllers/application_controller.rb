
# Exception class thrown when there is an attempt to save a new DOI in the session,
# but the article limit has been reached.
class DoiLimitReachedError < StandardError
end


# Wrapper around the session data which enforces the limit on the number of articles
# per report.  Controller code should read and write through this interface instead
# of the session directly.
class SavedDois
  
  attr_reader :saved
  
  
  def initialize(session_data)
    @saved = session_data
    if @saved.nil?
      @saved = {}
    end
  end
  
  
  def [](x)
    return @saved[x]
  end
  
  
  def []=(x, val)
    if @saved.length >= $ARTICLE_LIMIT
      raise DoiLimitReachedError, "Reached limit of #{$ARTICLE_LIMIT} DOIs"
    else
      @saved[x] = val
    end
  end
  
  
  def delete(val)
    @saved.delete(val)
  end
  
  
  def clone
    @saved.clone
  end
  
  
  def length
    @saved.length
  end
  
  
  def clear
    @saved = {}
  end
  
end


class ApplicationController < ActionController::Base

  protect_from_forgery

  before_filter :display_nav
  around_filter :save_session_dois
  
  
  # Sets @saved_dois based on the contents of the session, and saves it back to the
  # session after an action is run.
  def save_session_dois
    @saved_dois = SavedDois.new(session[:dois])
    @preview_list_count = @saved_dois.length
    
    yield  # Run the action
    
    session[:dois] = @saved_dois.saved
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
