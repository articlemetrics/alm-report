module Solr
  SOLR_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

  FILTER = "fq=doc_type:full&fq=!article_type_facet:#{URI::encode("\"Issue Image\"")}"

  FACETS = "facet=true&facet.field=journal&facet.field=article_type&facet." \
    "field=publication_date&facet.date=publication_date&facet.date.start" \
    "=2000-01-01T00:00:00Z&facet.date.end=NOW&facet.date.gap=%2B1YEAR"

  # The fields we want solr to return for each article by default.
  FL = "id,pmid,publication_date,received_date,accepted_date,title," \
      "cross_published_journal_name,author_display,editor_display,article_type,affiliate,subject," \
      "financial_disclosure"

  FL_METRIC_DATA = "id,alm_scopusCiteCount,alm_mendeleyCount,counter_total_all," \
      "alm_pmc_usage_total_all"

  FL_VALIDATE_ID = "id"

  ALL_JOURNALS = "All Journals"

  SORTS = {
    "Relevance" => "",
    "Date, newest first" => "publication_date desc",
    "Date, oldest first" => "publication_date asc",
    "Most views, last 30 days" => "counter_total_month desc",
    "Most views, all time" => "counter_total_all desc",
    "Most cited, all time" => "alm_scopusCiteCount desc",
    "Most bookmarked" => "sum(alm_citeulikeCount, alm_mendeleyCount) desc",
    "Most shared in social media" => "sum(alm_twitterCount, alm_facebookCount) desc",
    "Most tweeted" => "alm_twitterCount desc",
  }

  QUERY_PARAMS = [
    :everything, :author, :affiliate, :subject,
    :cross_published_journal_name, :financial_disclosure, :title,
    :publication_date, :id
  ]

  PROCESS_PARAMS = [
    :publication_days_ago, :datepicker1, :datepicker2, :filters,
    :current_page, :author_country, :institution, :ids, :rows, :facets
  ]

  WHITELIST = QUERY_PARAMS + PROCESS_PARAMS

end
