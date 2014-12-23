require 'rails_helper'
require 'solr/query_builder'

def build_query_test_once(params, expected, opts = nil)
  qb = Solr::QueryBuilder.new(params)
  qb.build
  qb.query[:q].should eq(expected)
  qb.query[opts.keys[0]].should eq(opts.values[0]) if opts
end

def build_page_block_test_once(params, expected)
  qb = Solr::QueryBuilder.new(params)
  qb.send(:page_block).should eq(expected)
end

describe Solr::QueryBuilder do
  it "can build simple queries" do
    build_query_test_once({ everything: "everyFoo" }, "everything:everyFoo")

    build_query_test_once(
      { everything: "foo bar blaz" },
      'everything:"foo bar blaz"'
    )

    build_query_test_once(
      { everything: "everyTitle", title: "titleFoo" },
      "everything:everyTitle AND title:titleFoo"
    )

    build_query_test_once(
      { author: "Joe Bob", subject: "Virology" },
      'author:"Joe Bob" AND subject:Virology'
    )
  end

  it "knows how to deal with empty fields" do
    # Empty fields should not be added.
    build_query_test_once(
      { everything: "ignoreRest", author: "", subject: "  " },
      "everything:ignoreRest"
    )
  end

  it "can handle institution and author_country both mapping to affiliate" do
    # Hack where the "pseudo-fields" author_country and institution both map to
    # the actual solr field affiliate.
    build_query_test_once(
      { author_country: "authorCountry" },
      "affiliate:authorCountry"
    )

    build_query_test_once(
      { everything: "everythingInst", institution: "foo institution" },
      'affiliate:"foo institution" AND everything:everythingInst'
    )

    build_query_test_once(
      { author_country: "france", institution: "university of lyon" },
      'affiliate:(france AND "university of lyon")'
    )

    build_query_test_once(
      {
        everything: "some keywords", author_country: "USA",
        institution: "stanford u", subject: "ebola virus"
      },
      'affiliate:(USA AND "stanford u") AND everything:"some keywords" AND ' \
      'subject:"ebola virus"'
    )
  end

  it "removes All Journals from list of journals" do
    # cross_published_journal_name should be ignored if it equals "All Journals"
    build_query_test_once(
      { everything: "fooCross", filters: ["PLoSONE"] },
      'everything:fooCross',
      {fq: "cross_published_journal_key:PLoSONE"}
    )

    build_query_test_once(
      {
        everything: "fooNoJournal",
        filters: ["All Journals"]
      },
      "everything:fooNoJournal"
    )
  end

  it "can build a simple page block" do
    build_page_block_test_once({}, "rows=25")
    # Page 1 is the default
    build_page_block_test_once({ current_page: "1" }, "rows=25")
    build_page_block_test_once({ current_page: "2" }, "rows=25&start=25")
    build_page_block_test_once({ current_page: "3" }, "rows=25&start=50")
    build_page_block_test_once({ current_page: "4" }, "rows=25&start=75")
  end

  it "rows params override default paging" do
    build_page_block_test_once({ rows: 500 }, "rows=500")
  end

  it "doesn't have interactions between build_page_block and build" do
    params = { everything: "hi", title: "bye" }
    qb = Solr::QueryBuilder.new(params)
    qb.send(:page_block).should eq("rows=25")
    qb.build
    qb.query[:q].should eq("everything:hi AND title:bye")

    params = { everything: "bad", title: "business", current_page: 2, rows: 475 }
    qb = Solr::QueryBuilder.new(params)
    qb.send(:page_block).should eq("rows=475&start=475")
    qb.build
    qb.query[:q].should eq("everything:bad AND title:business")
  end

  it "generates the correct URL for a query" do
    qb = Solr::QueryBuilder.new(everything: "everyTitle", title: "titleFoo")
    qb.build
    url = "http://api.plos.org/search?q=everything%3AeveryTitle+AND+title%3A" \
      "titleFoo&fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&" \
      "fl=id,pmid,publication_date,received_date,accepted_date,title,cross_" \
      "published_journal_name,author_display,editor_display,article_type,affi" \
      "liate,subject,financial_disclosure&wt=json&facet=false&rows=25&hl=false"
    qb.url.should eq(url)
  end

  it "doesn't raise an exception if a param is nil" do
    build_query_test_once(
      {everything: nil, title: "testing"},
      "title:testing"
    )
  end

  it "ignores all sorts that are not whitelisted" do
    sort = "sum(malformed,"
    qb = Solr::QueryBuilder.new(everything: "testing", sort: sort)
    qb.build
    qb.send(:sort).should eq(nil)
  end

  it "takes whitelisted sorts into account" do
    sort = "publication_date desc"
    qb = Solr::QueryBuilder.new(everything: "testing", sort: sort)
    qb.build
    qb.send(:sort).should eq("&sort=publication_date%20desc")
  end

  it "accepts HashWithIndifferentAccess as a parameter" do
    params = ActiveSupport::HashWithIndifferentAccess.new(
      "everything" => "testing"
    )
    qb = Solr::QueryBuilder.new(params)
    qb.build
    qb.query[:q].should eq("everything:testing")
  end

  it "doesn't ignore publication_date parameter (regression test for issue #50)" do
    params = {
      everything: "cancer",
      author: "",
      author_country: "",
      institution: "",
      subject: "",
      filters: ["All Journals"],
      financial_disclosure: "",
      publication_date: "[2014-09-03T14:01:32Z TO 2014-10-03T14:01:32Z]"
    }
    qb = Solr::QueryBuilder.new(params)
    qb.build
    qb.query[:q].should eq(
      "everything:cancer AND publication_date:[2014-09-03T14:01:32Z TO " \
      "2014-10-03T14:01:32Z]"
    )
  end

  it "parses date range -1 (all time)" do
    params = {
      publication_days_ago: "-1"
    }
    qb = Solr::QueryBuilder.new(params)
    qb.build

    assert_nil(qb.start_time)
    assert_nil(qb.end_time)
    assert_nil(qb.params[:publication_date])
  end

  it "parses a specific date range and build the correct string" do
    params = {
      publication_days_ago: "0",
      datepicker1: "09-15-2012",
      datepicker2: "02-28-2013"
    }

    qb = Solr::QueryBuilder.new(params)
    qb.build

    assert_equal("[2012-09-15T00:00:00Z TO 2013-02-28T23:59:59Z]",
        qb.params[:publication_date])
  end

  it "publication_days_ago" do
    Timecop.travel(Date.strptime("2013-03-01", "%Y-%m-%d").to_time)
    params = {
      publication_days_ago: "30"
    }

    qb = Solr::QueryBuilder.new(params)
    qb.build

    assert_equal("[2013-01-30T00:00:00Z TO 2013-03-01T00:00:00Z]",
        qb.params[:publication_date])

    Timecop.return

    # TODO: test end day before start day and other error cases.
  end

  it "adjusts the rows for multiple ids" do
    params = { ids: 103.times.map{ |i| i} }

    qb = Solr::QueryBuilder.new(params)
    qb.build
    expect(qb.url).to include("rows=206")
  end

  it "will allow supplied rows parameter to override" do
    params = { everything: "biology", rows: 200 }

    qb = Solr::QueryBuilder.new(params)
    qb.build

    expect(qb.url).to include("rows=200")
  end
end
