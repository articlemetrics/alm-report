require "date"
require "test_helper"

class SolrRequestTest < ActiveSupport::TestCase
  
  def build_query_test_once(params, expected)
    req = SolrRequest.new(params)
    assert_equal(expected, req.build_query)
  end
  
  
  test "build_query_test" do
    build_query_test_once({:everything => "everyFoo"}, "q=everything:everyFoo")
    build_query_test_once({:everything => "foo bar blaz"}, 'q=everything:"foo bar blaz"')
    build_query_test_once({:everything => "everyTitle", :title => "titleFoo"},
        "q=everything:everyTitle AND title:titleFoo")
    build_query_test_once({:author => "Joe Bob", :subject => "Virology"},
        'q=author:"Joe Bob" AND subject:Virology')
        
    # Empty fields should not be added.
    build_query_test_once({:everything => "ignoreRest", :author => "", :subject => "  "},
        "q=everything:ignoreRest")
        
    # Hack where the "pseudo-fields" author_country and institution both map to the actual
    # solr field affiliate.
    build_query_test_once({:author_country => "authorCountry"}, "q=affiliate:authorCountry")
    build_query_test_once({:everything => "everythingInst", :institution => "foo institution"},
        'q=affiliate:"foo institution" AND everything:everythingInst')
    build_query_test_once({:author_country => "france", :institution => "university of lyon"},
        'q=affiliate:(france AND "university of lyon")')
    build_query_test_once({:everything => "some keywords", :author_country => "USA",
        :institution => "stanford u", :subject => "ebola virus"},
        'q=affiliate:(USA AND "stanford u") AND everything:"some keywords" AND subject:"ebola virus"')
        
    # cross_published_journal_name should be ignored iff it equals "All Journals".
    build_query_test_once({:everything => "fooCross", :cross_published_journal_name => "PLOS ONE"},
        'q=cross_published_journal_name:"PLOS ONE" AND everything:fooCross')
    build_query_test_once(
        {:everything => "fooNoJournal", :cross_published_journal_name => "All Journals"},
        "q=everything:fooNoJournal")
  end

  
  test "parse_date_range_test" do
    start_date, end_date = SolrRequest.parse_date_range("-1", nil, nil)
    assert_nil(start_date)
    assert_nil(end_date)
    assert_nil(SolrRequest.build_date_range(nil, nil))
        
    start_date, end_date = SolrRequest.parse_date_range("0", "09-15-2012", "02-28-2013")
    assert_equal("[2012-09-15T00:00:00Z TO 2013-02-28T23:59:59Z]",
        SolrRequest.build_date_range(start_date, end_date))
        
    def SolrRequest.get_now
      Date.strptime("2013-03-01", "%Y-%m-%d").to_time
    end
        
    start_date, end_date = SolrRequest.parse_date_range("30", nil, nil)
    assert_equal("[2013-01-30T00:00:00Z TO 2013-03-01T00:00:00Z]",
        SolrRequest.build_date_range(start_date, end_date))

    # TODO: test end day before start day and other error cases.
  end
  
  
  def build_page_block_test_once(params, expected)
    req = SolrRequest.new(params)
    assert_equal(expected, req.build_page_block)
  end
  
  
  test "build_page_block_test" do
    build_page_block_test_once({}, "rows=25")
    
    # Page 1 is the default
    build_page_block_test_once({:current_page => "1"}, "rows=25")
    
    build_page_block_test_once({:current_page => "2"}, "rows=25&start=26")
    build_page_block_test_once({:current_page => "3"}, "rows=25&start=51")
    build_page_block_test_once({:current_page => "4"}, "rows=25&start=76")
    
    # If start and/or rows params are present, this should override the default paging.
    build_page_block_test_once({:start => 17}, "rows=25&start=17")
    build_page_block_test_once({:start => 100, :rows => 200}, "rows=200&start=100")
    build_page_block_test_once({:rows => 500}, "rows=500")
    
    # Test that build_page_block doesn't interfere with build_query
    params = {:everything => "hi", :title => "bye"}
    req = SolrRequest.new(params)
    assert_equal("rows=25", req.build_page_block)
    assert_equal("q=everything:hi AND title:bye", req.build_query)
    
    params = {:everything => "bad", :title => "business", :start => 41, :rows => 475}
    req = SolrRequest.new(params)
    assert_equal("rows=475&start=41", req.build_page_block)
    assert_equal("q=everything:bad AND title:business", req.build_query)
  end

end
