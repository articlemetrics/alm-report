require "test_helper"

class SolrRequestTest < ActiveSupport::TestCase
  
  def build_query_test_once(params, expected)
    req = SolrRequest.new(params)
    assert_equal(expected, req.build_query)
  end
  
  test "build_query_test" do
    build_query_test_once({:everything => "everyFoo"}, "q=everything:everyFoo")
    build_query_test_once({:everything => "foo bar blaz"}, 'q=everything:"foo%20bar%20blaz"')
    build_query_test_once({:everything => "\I'm !\"1337\"&"}, "q=everything:\"I'm%20!%221337%22&\"")
    build_query_test_once({:everything => "everyFoo", :title => "titleFoo"},
        "q=everything:everyFoo%20AND%20title:titleFoo")
    build_query_test_once({:author => "Joe Bob", :subject => "Virology"},
        'q=author:"Joe%20Bob"%20AND%20subject:Virology')
        
    # Empty fields should not be added.
    build_query_test_once({:everything => "ignoreRest", :author => "", :subject => "  "},
        "q=everything:ignoreRest")
  end

end
