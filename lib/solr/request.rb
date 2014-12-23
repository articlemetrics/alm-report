require "date"
require "net/http"
require "open-uri"
require "json"

# Interface to solr search for PLOS articles.  A thin wrapper around the solr http API.
module Solr
  class Request
    include Performance

    # Creates a solr request.  The query (q param in the solr request) will be based on
    # the values of the params passed in, so these should all be valid entries in the PLOS schema.
    # If the fl argument is non-nil, it will specify what result fields to return from
    # solr; otherwise all fields that we are interested in will be returned.
    def initialize(params, fl=nil)
      @params = params
      @fl = fl
    end

    def self.send_query(url)
      start_time = Time.now
      resp = Net::HTTP.get_response(URI.parse(url))

      end_time = Time.now
      Rails.logger.debug "SOLR Request took #{end_time - start_time} seconds\n#{url}"

      if resp.code != "200"
        raise Error, "Server returned #{resp.code}: " + resp.body
      end
      return JSON.parse(resp.body)
    end

    # Returns a list of JSON entities for article results given a json response from solr.
    def self.parse_docs(json)
      docs = json["response"]["docs"]
      docs.map do |doc|
        doc = fix_data(doc)
        SearchResult.new(doc, :plos)
      end
    end

    def parse_facets(json)
      facets = Facet.new
      counts = json["facet_counts"]

      facets.add(%w[journal article_type].map do |name|
        facet = {}
        facet[name] = Hash[
          *counts["facet_fields"][name].map.with_index do |f, i|
            i % 2 == 1 ? {count: f} : f
          end
        ]
        facet
      end)

      facets.add("publication_date" => Hash[
        counts["facet_dates"]["publication_date"].select do |k, v|
          k.start_with? "2"
        end.map{ |date, count| [date, {count: count}] }.reverse
      ])

      facets.each do |name, values|
        (@params[:facets] || []).each do |facet|
          if values.find{|key, value| key == facet[:value]}
            facets.select(name: name, value: facet[:value])
          end
        end
      end

      facets
    end

    # Performs a single solr search, based on the parameters set on this object.
    # Returns a tuple of the documents retrieved, and the total number of results.
    def query
      url = query_builder.url
      json = Request.send_query(url)

      return {
        docs: Request.parse_docs(json),
        facets: parse_facets(json),
        found: json["response"]["numFound"],
        metadata: metadata
      }
    end

    # The goal is to mimic advanced search filter on the PLOS (journal) side
    # 1. use fq (filter query) with cross_published_journal_key field
    # 2. display the journal names that are tied to the
    #    cross_published_journal_key field on the front end
    def self.get_journals
      SearchPlos::JOURNALS
    end

    # There are a handful of special cases where we want to display a "massaged"
    # version of what solr returns, instead of the direct value.  This method
    # takes care of all of those.
    def self.fix_data(doc)
      Request.fix_date(doc, "publication_date")
      Request.fix_date(doc, "received_date")
      Request.fix_date(doc, "accepted_date")

      # For articles cross-published in PLOS Collections, we want to display the
      # original journal name throughout the app.
      if doc["cross_published_journal_name"] && doc["cross_published_journal_name"].length > 1
        collections_index = doc["cross_published_journal_name"].index("PLOS Collections")
        if !collections_index.nil?
          new_index = collections_index == 0 ? 1 : 0
          doc["cross_published_journal_name"][0] = doc["cross_published_journal_name"][new_index]
        end
      end
      doc
    end

    # Substitutes a formatted value for a date field of the given name
    # in the solr data structure.
    def self.fix_date(doc, date_field_name)
      if doc[date_field_name]
        doc[date_field_name] = Date.strptime(doc[date_field_name], SOLR_TIMESTAMP_FORMAT)
      end
      doc
    end

    # helper function for retrieving data from solr
    def self.get_data_helper(report_dois, cache_postfix, fields_to_retrieve)
      # TODO should we return emtpy array or nil if report_dois is nil / empty?

      all_results = {}
      if (report_dois.first.kind_of? String)
        dois = report_dois.clone
      else
        dois = report_dois.map { |report_doi| report_doi.doi }
      end

      # get solr data from cache
      if (!cache_postfix.nil?)
        dois.delete_if  do | doi |
          results = Rails.cache.read("#{doi}.#{cache_postfix}")
          if !results.nil?
            all_results[doi] = results
            true
          end
        end
      end

      while dois.length > 0 do
        subset_dois = dois.slice!(0, ENV["SOLR_MAX_DOIS"].to_i)
        q = subset_dois.map { | doi | "id:\"#{doi}\"" }.join(" OR ")

        url = "#{ENV["SOLR_URL"]}?q=#{URI::encode(q)}&#{FILTER}&fl=#{fields_to_retrieve}" \
            "&wt=json&facet=false&rows=#{subset_dois.length}"

        json = Request.send_query(url)

        docs = json["response"]["docs"]
        docs.each do |doc|
          doc = fix_data(doc)
          all_results[doc["id"]] = doc

          # store solr data in cache
          if (!cache_postfix.nil?)
            Rails.cache.write("#{doc["id"]}.#{cache_postfix}", doc, :expires_in => 1.day)
          end
        end
      end

      return all_results
    end

    # Retrieves article related information from solr for a given list of DOIs.
    def self.get_data_for_articles(report_dois)
      measure(dois: report_dois) do
        Request.get_data_helper(report_dois, "solr", FL)
      end
    end

    def self.validate_dois(report_dois)
      measure(dois: report_dois) do
        Request.get_data_helper(report_dois, nil, FL_VALIDATE_ID)
      end
    end

    # Performs a batch query for articles based on the list of PubMed IDs passed in.
    # Returns a hash of PMID => solr doc, with only id, pmid, and publication_date defined
    # in the solr docs.
    def self.query_by_pmids(pmids)
      return unless pmids.present?
      q = pmids.map {|pmid| "pmid:\"#{pmid}\""}.join(" OR ")
      url = "#{ENV["SOLR_URL"]}?q=#{URI::encode(q)}&#{FILTER}" \
          "&fl=id,publication_date,pmid&wt=json&facet=false&rows=#{pmids.length}"
      json = Request.send_query(url)
      docs = json["response"]["docs"]
      results = {}
      docs.each do |doc|
        if doc["publication_date"]
          doc["publication_date"] = Date.strptime(doc["publication_date"], SOLR_TIMESTAMP_FORMAT)
        end
        results[doc["pmid"].to_i] = SearchResult.new(doc, :plos)
      end
      results
    end

    private

    def metadata
      metadata = {}
      if @query_builder.params[:publication_date].present?
        metadata[:publication_date] = query_builder.params[:publication_date][1..-2].
          split(" TO ").map{ |date| DateTime.parse(date) }
      end
      metadata
    end

    def query_builder
      @query_builder ||= QueryBuilder.new(@params, @fl)
    end
  end
end
