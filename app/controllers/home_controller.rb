class HomeController < ApplicationController
  # Update session via ajax call
  def update_session
    initial_count = @cart.size

    # don't update session when article_limit reached
    return render json: { status: "limit", delta: 0 } \
      unless initial_count < ENV["ARTICLE_LIMIT"].to_i

    article_ids = params[:article_ids]

    case params[:mode]
    when "ADD" then @cart.add(article_ids)
    when "REMOVE" then @cart.remove(article_ids)
    end
    render json: { status: "success", delta: @cart.size - initial_count }.to_json
  end

  # Parse array of keys in the form "10.1371/journal.pone.0052192|12345678",
  # i.e. a doi and timestamp separated by a '|' character. Returns a hash.
  # Hash is empty if params[:article_ids] is nil or limit reached
  def parse_article_keys(keys, count = 0)
    limit = ENV["ARTICLE_LIMIT"].to_i - count
    return {} unless limit > 0

    article_ids = Array(keys)[0...limit].reduce({}) do |hash, id|
      fields = id.split("|")
      hash.merge(fields.first => fields.last.to_i)
    end
  end

  # Simple AJAX action that returns the count of articles stored in the session.
  def get_article_count
    render json: @cart.size
  end

  # Queries solr for the results used by select_all_search_results.
  def get_all_results
    # For efficiency, we want to query solr for the smallest number of results.
    # However, this is difficult because the user may have already selected
    # some articles from various pages of the search results, and there is no
    # easy way to determine the intersection of this with the search we're about
    # to do.  Using article_limit * 2 as our requested number of results handles
    # various pathological cases such as the user having checked every other
    # search result.
    limit = ENV["ARTICLE_LIMIT"].to_i * 2
    params[:rows] = rows = 200
    # solr usually returns 500s if you try to retreive all 1000 articles at once,
    # so we do paging here (with a larger page size than in the UI).

    results = []
    for page in 1 .. (limit / rows)
      params[:current_page] = page
      docs = Search.find(params)[:docs]
      results += docs
      break if docs.size < rows
    end
    results
  end
  private :get_all_results

  # Ajax action that handles the "Select all nnn articles" link.  Selects
  # *all* of the articles from the search, not just those on the current page.
  # (Subject to the article limit.)
  def select_all_search_results
    initial_count = @cart.size

    # This is a little weird... if the user has no more capacity before the
    # article limit, return an error status, but if at least one article can
    # be added, return success.
    if initial_count >= ENV["ARTICLE_LIMIT"].to_i
      status = "limit"
    else
      status = "success"
      begin
        docs = get_all_results
      rescue Solr::Error
        logger.warn("Error querying solr: #{$!}")

        # Send a json response, instead of the rails 500 HTML page.
        render json: {status: "error"}.to_json, status: 500
        return
      end
      docs.each do |doc|
        @cart[doc.id] = doc
      end
    end
    render json: {status: status, delta: @cart.size - initial_count}.to_json
  end

  # Action that clears any DOIs in the session and redirects to home.
  def start_over
    session.delete(:facets)
    @cart.clear
    redirect_to root_path
  end
end
