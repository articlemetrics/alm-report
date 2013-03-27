
class HomeController < ApplicationController

  def index
  end

  def add_articles
    q = SolrRequest.new
    q.keyword = params[:keyword]

    # TODO: set additional solr search params.

    @docs, @total_found = q.query
  end
  
end
