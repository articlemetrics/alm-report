class StaticPagesController < ApplicationController

  def display_nav
    @display_nav = false
  end  

  def about
    @title = "About"
  end

  def privacy_policy
    @title = "Privacy Policy"
  end

  def terms_of_use
    @title = "Terms of Use"
  end

  def search_help
    @title = "Search Help"
  end
end
