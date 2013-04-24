
# Controller that handles the "Find Articles by DOI/PMID" page.
class IdController < ApplicationController
  
  def index
    @tab = :select_articles
    @title = "Find Articles by DOI/PMID"
  end
  
end
