require 'spec_helper'

describe "sorting results", type: :feature, vcr: true do
  if Search.plos?
    it "sorts PLOS", js: true do
      visit "/"
      fill_in "everything", with: "cancer"
      click_button "Search"
      page.should have_select("sort", options: Solr::SORTS.keys)
    end
  elsif Search.crossref?
    it "sorts CrossRef", js: true do
      visit "/"
      fill_in "everything", with: "cancer"
      click_button "Search"
      page.should have_select("sort", options: SearchCrossref::SORTS.keys)
    end
  end
end
