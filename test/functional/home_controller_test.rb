require 'test_helper'

class HomeControllerTest < ActionController::TestCase
  test "should get index" do
    stub_request(:get,
      "http://api.plos.org/search?facet=true&facet.field=cross_published_journal_key&facet.mincount=1&fq=!article_type_facet:%22Issue%20Image%22&q=*:*&rows=0&wt=json"
    ).to_return(File.open('test/fixtures/solr_request_get_journal_name_key.raw'))
    get :index
    assert_response :success
  end
end
