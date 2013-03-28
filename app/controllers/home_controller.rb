
class HomeController < ApplicationController

  def index
  end

  def add_articles
    
    # Strip out form params not relevant to solr.
    solr_params = {}
    params.keys.each do |key|
      if !["utf8", "commit", "controller", "action"].include?(key.to_s)
        solr_params[key.to_sym] = params[key]
      end
    end
    q = SolrRequest.new(solr_params)
    @docs, @total_found = q.query
  end
  
end
