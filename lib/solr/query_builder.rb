module Solr
  class QueryBuilder
    attr_reader :page_block, :query, :params, :end_time, :start_time

    def initialize(params, fl = nil)
      @params = params.dup
      @sort = @params[:sort]

      @fl = fl || Request::FL
      @page_block = build_page_block
      @query = {}
    end

    def fl
      "fl=#{@fl}"
    end

    # Returns the portion of the solr URL with the q parameter, specifying
    # the search. Note that the results of this method *must* be URL-escaped
    # before use.
    def build
      clean_params
      build_filter_journals
      build_affiliate_param
      build_date_range
      @query[:q] = @params.sort_by { |k, _| k }.select do |k, _|
        Request::QUERY_PARAMS.include?(k.to_sym)
      end.map do |k, v|
        unless %w(affiliate publication_date id).include?(k.to_s) # Pre-formatted
          v = quote_if_spaces(v)
        end
        "#{k}:#{v}"
      end.join(" AND ")

      Rails.logger.info("Solr query: #{@query}")
      @query
    end

    # Returns the portion of Solr URL with the query parameter & journal filter
    def build_advanced
      build_filter_journals

      if @params.has_key?(:unformattedQueryId)
        @query[:q] = @params[:unformattedQueryId].strip
      end
      @query
    end

    # Adds leading & trailing double-quotes to string if it contains whitespace.
    def quote_if_spaces(s)
      if /\s/.match(s)
        s = "\"#{s}\""
      end
      s
    end

    # The search page uses two form fields, author_country and institution, that
    # are both implemented by mapping onto the same field in the solr schema:
    # affiliate. This method handles building the affiliate param based on the
    # other two (whether or not they are present). It will also delete the two
    # "virtual" params as a side-effect.

    def build_affiliate_param
      parts = [@params[:author_country], @params[:institution]]
      parts = parts.compact.map do |part|
        quote_if_spaces(part)
      end
      if parts.present?
        affiliate = parts.join(" AND ")
        if parts.size > 1
          @params[:affiliate] = "(#{affiliate})"
        else
          @params[:affiliate] = affiliate
        end
      end
    end

    # Returns the fragment of the URL having to do with paging; specifically,
    # the rows and start parameters.  These can be passed in directly to the
    # constructor, or calculated based on the current_page param, if it's present.
    def build_page_block
      rows = @params[:rows] || ENV["PER_PAGE"]
      page = @params[:current_page] || "1"

      result = "rows=#{rows}"

      page = page.to_i - 1
      if page > 0
        result << "&start=#{page * rows.to_i}"
      end
      result
    end

    def common_params
      "&#{Request::FILTER}&#{fl}&wt=json&facet=false&#{@page_block}"
    end

    def sort
      if Request::SORTS.values.include? @sort
        "&sort=#{URI::encode(@sort)}"
      end
    end

    def url
      # :unformattedQueryId comes from advanced search
      @params.has_key?(:unformattedQueryId) ? build_advanced : build
      "#{ENV["SOLR_URL"]}?#{query_param}#{common_params}#{sort}&hl=false"
    end

    private

    def build_filter_journals
      if @params.has_key?(:filterJournals)
        @query[:fq] = @params[:filterJournals].map do |filter_journal|
          "cross_published_journal_key:#{filter_journal}"
        end.join(" OR ")
      end
    end

    def query_param
      unless @query[:q].present?
        @query[:q] = "*:*"
      end
      @query.to_param
    end

    private

    # Logic for creating a limit on the publication_date for a query. All params
    # are strings. Legal values for days_ago are "-1", "0", or a positive integer.
    # If -1, the method returns (nil, nil) (no date range specified). If 0, the
    # values of start_date and end_date are used to construct the returned range.
    # If positive, the range extends from (today - days_ago) to today. start_date
    # and end_date, if present, should be strings in the format %m-%d-%Y.
    def parse_date_range
      return unless @params[:publication_days_ago].present?

      days_ago = @params[:publication_days_ago].to_i
      start_date = @params[:datepicker1]
      end_date = @params[:datepicker2]

      @end_time = Time.new
      if days_ago == -1  # All time; default.  Nothing to do.
        @start_time, @end_time = nil, nil
      elsif days_ago == 0  # Custom date range
        @start_time = Date.strptime(start_date, "%m-%d-%Y")
        @end_time = DateTime.strptime(end_date + " 23:59:59", "%m-%d-%Y %H:%M:%S")
      else  # days_ago specifies start date; end date now
        @start_time = end_time - (3600 * 24 * days_ago)
      end
    end

    # Returns a legal value constraining the publication_date for the given start
    # and end DateTimes. Returns nil if either of the arguments are nil.
    def build_date_range
      parse_date_range
      if @start_time && @end_time
        times = [@start_time.strftime(Request::SOLR_TIMESTAMP_FORMAT),
          @end_time.strftime(Request::SOLR_TIMESTAMP_FORMAT)]
        @params[:publication_date] = "[#{times.join(" TO ")}]"
      end
    end

    def clean_params
      # Strip out empty and only keep whitelisted params
      @params.delete_if do |k, v|
        v.blank? || !Request::WHITELIST.include?(k.to_sym)
      end

      # Strip out the placeholder "all journals" journal value.
      @params.delete_if do |k, v|
        [k.to_s, v] == ["filterJournals", [Request::ALL_JOURNALS]]
      end
    end
  end
end
