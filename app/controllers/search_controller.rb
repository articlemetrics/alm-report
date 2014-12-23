class SearchController < ApplicationController
  before_filter { journals if Search.plos? }

  def index
    params[:advanced] ? advanced : simple
  end

  def show
    @tab = :select_articles
    @title = "Add Articles"

    session[:params] = params
    search = Search.find(params)

    @results = search[:docs]
    @total_found = search[:found]
    @metadata = search[:metadata]

    session[:facets] = search[:facets]
    @facets = search[:facets]

    if @cart.items.present?
      @results.each do |result|
        result.checked = true if @cart.items.has_key?(result.id)
      end
    end

    set_paging_vars(params[:current_page])
  end

  def facets
    @facets = session[:facets]
    redirect_to(root_path) && return unless @facets

    params[:facets].each do |facet|
      @facets.select(name: facet[:name], value: facet[:value])
    end

    redirect_to search_path(session[:params].merge(@facets.params))
  end

  private

  def simple
    @tab = :select_articles

    render "simple"
  end

  def advanced
    @tab = :select_articles
    @title = "Advanced Search"

    render "advanced"
  end

  # PLOS

  def journals
    @journals = Solr::Request.get_journals
  end
end
