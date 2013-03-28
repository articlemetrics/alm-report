require "test_helper"

class SolrRequestTest < ActiveSupport::TestCase
  
  def build_query_test_once(params, expected)
    req = SolrRequest.new(params)
    assert_equal(expected, req.build_query)
  end
  
  test "build_query_test" do
    build_query_test_once({:everything => "everyFoo"}, "q=everything%3AeveryFoo")
    build_query_test_once({:everything => "foo bar blaz"}, "q=everything%3A%22foo%20bar%20blaz%22")
    build_query_test_once({:everything => "\I'm !\"1337\"&"},
        "q=everything%3A%22I'm%20!%221337%22&%22")
    build_query_test_once({:everything => "everyFoo", :title => "titleFoo"},
        "q=everything%3AeveryFoo%20AND%20title%3AtitleFoo")
    build_query_test_once({:author => "Joe Bob", :subject => "Virology"},
        'q=author%3A%22Joe%20Bob%22%20AND%20subject%3AVirology')
        
    # Empty fields should not be added.
    build_query_test_once({:everything => "ignoreRest", :author => "", :subject => "  "},
        "q=everything%3AignoreRest")
  end
  
  # Tests that fragments produced by build_query are legal URIs.
  test "build_query_legal_uri_test" do
    req = SolrRequest.new({:everything => "with space"})
    URI.parse("http://api.plos.org/search?#{req.build_query}&foo=bar")
  end

end
