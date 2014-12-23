require 'rails_helper'

describe SearchController do
  describe 'GET index' do
    it 'renders the index template' do
      get :index
      expect(response).to render_template("simple")
    end
  end

  describe "GET show" do
    it "renders the show template" do
      stub_request(
        :get,
        %r{http://api.crossref.org/works.*}
      ).to_return(File.open("spec/fixtures/api_crossref_cancer.raw"))

      stub_request(
        :get,
        "http://api.plos.org/search?facet=false&fl=id,pmid,publication_date," \
        "received_date,accepted_date,title,cross_published_journal_name," \
        "author_display,editor_display,article_type,affiliate,subject," \
        "financial_disclosure&fq=doc_type:full&" \
        "fq=!article_type_facet:%22Issue%20Image%22" \
        "&hl=false&q=everything:cancer&rows=25&wt=json"

      ).to_return(File.open("spec/fixtures/api_plos_cancer_search.raw"))
      get :show, {
        utf8: "✓",
        everything: "cancer",
        author: "",
        author_country: "",
        institution: "",
        publication_days_ago: -1,
        datepicker1: "",
        datepicker2: "",
        subject: "",
        filters: ["All Journals"],
        financial_disclosure: "",
        commit: "Search",
        x: "Y"
      }
      expect(response).to render_template("show")
    end
  end

  # PLOS specific spec, because there's no advanced search for CrossRef
  if Search.plos?
    describe "GET /search/advanced" do
      it "renders the advanced template" do
        stub_request(:get,
          "http://api.plos.org/search?facet=true&facet.field=cross_published_journal_key&facet.mincount=1&fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&q=*:*&rows=0&wt=json"
        ).to_return(File.open('spec/fixtures/solr_request_get_journal_name_key.raw'))

        get :index, advanced: true
        expect(response).to render_template("advanced")
      end
    end

    describe "GET show from advanced search" do
      it "renders the show template" do
        url = "http://api.plos.org/search?facet=false&fl=id,pmid," \
          "publication_date,received_date,accepted_date,title," \
          "cross_published_journal_name,author_display,editor_display," \
          "article_type,affiliate,subject,financial_disclosure&" \
          "fq=cross_published_journal_key:PLoSCompBiol&" \
          "fq=doc_type:full&" \
          "fq=!article_type_facet:%22Issue%20Image%22&hl=false" \
          "&q=everything:biology&rows=25&wt=json"
        stub_request(:get, url).
          to_return(File.open('spec/fixtures/api_plos_biology_advanced.raw'))

        get :show, {
          queryFieldId: "everything",
          queryTermId: "",
          startDateAsStringId: "",
          endDateAsStringId: "",
          unformattedQueryId: "everything:biology",
          commit: "Search",
          journalOpt: "some",
          filters: ["PLoSCompBiol"],
          utf8: "✓"
        }

        expect(response).to render_template("show")
      end
    end
  end

end
