require 'spec_helper'
require 'alm_request'

describe AlmRequest do

  context "get ALM Data for articles" do

    it "get ALM data for articles" do
      report = Report.new
      report.save

      dois = [
        '10.1371/journal.pone.0064652',
        '10.1371/journal.pmed.0020124'
      ]

      report.add_all_dois(dois)

      params = {}
      params[:ids] = dois.join(",")
      url = AlmRequest.get_alm_url(params)

      body = File.read("#{fixture_path}alm_good_response.json")

      stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

      data = AlmRequest.get_data_for_articles(report.report_dois)

      data.size.should eq(2)

      data['10.1371/journal.pone.0064652'][:plos_html].should eq(308)
      data['10.1371/journal.pone.0064652'][:plos_pdf].should eq(4)
      data['10.1371/journal.pone.0064652'][:plos_xml].should eq(7)
      data['10.1371/journal.pone.0064652'][:plos_total].should eq(319)

      data['10.1371/journal.pone.0064652'][:pmc_views].should eq(0)
      data['10.1371/journal.pone.0064652'][:pmc_pdf].should eq(1)
      data['10.1371/journal.pone.0064652'][:pmc_total].should eq(1)

      data['10.1371/journal.pone.0064652'][:total_usage].should eq(320)
      data['10.1371/journal.pone.0064652'][:viewed_data_present].should eq(true)

      data['10.1371/journal.pone.0064652'][:pmc_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:crossref_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:scopus_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:cited_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:citeulike].should eq(0)
      data['10.1371/journal.pone.0064652'][:mendeley].should eq(0)
      data['10.1371/journal.pone.0064652'][:saved_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:nature].should eq(0)
      data['10.1371/journal.pone.0064652'][:research_blogging].should eq(0)
      data['10.1371/journal.pone.0064652'][:scienceseeker].should eq(0)
      data['10.1371/journal.pone.0064652'][:facebook].should eq(0)
      data['10.1371/journal.pone.0064652'][:twitter].should eq(0)
      data['10.1371/journal.pone.0064652'][:wikipedia].should eq(0)
      data['10.1371/journal.pone.0064652'][:discussed_data_present].should eq(false)


      data['10.1371/journal.pmed.0020124'][:plos_html].should eq(568181)
      data['10.1371/journal.pmed.0020124'][:plos_pdf].should eq(106120)
      data['10.1371/journal.pmed.0020124'][:plos_xml].should eq(2161)
      data['10.1371/journal.pmed.0020124'][:plos_total].should eq(676462)

      data['10.1371/journal.pmed.0020124'][:pmc_views].should eq(108674)
      data['10.1371/journal.pmed.0020124'][:pmc_pdf].should eq(18606)
      data['10.1371/journal.pmed.0020124'][:pmc_total].should eq(127280)

      data['10.1371/journal.pmed.0020124'][:total_usage].should eq(803742)
      data['10.1371/journal.pmed.0020124'][:viewed_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:pmc_citations].should eq(208)
      data['10.1371/journal.pmed.0020124'][:crossref_citations].should eq(528)
      data['10.1371/journal.pmed.0020124'][:scopus_citations].should eq(915)
      data['10.1371/journal.pmed.0020124'][:cited_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:citeulike].should eq(364)
      data['10.1371/journal.pmed.0020124'][:mendeley].should eq(4064)
      data['10.1371/journal.pmed.0020124'][:saved_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:nature].should eq(0)
      data['10.1371/journal.pmed.0020124'][:research_blogging].should eq(9)
      data['10.1371/journal.pmed.0020124'][:scienceseeker].should eq(1)
      data['10.1371/journal.pmed.0020124'][:facebook].should eq(4253)
      data['10.1371/journal.pmed.0020124'][:twitter].should eq(640)
      data['10.1371/journal.pmed.0020124'][:wikipedia].should eq(9)
      data['10.1371/journal.pmed.0020124'][:discussed_data_present].should eq(true)

    end

    it "fail to get ALM data for articles" do
      report = Report.new
      report.save

      dois = [
        '10.1371/journal.pone.ASDFGQW'
      ]

      report.add_all_dois(dois)

      params = {}
      params[:ids] = dois.join(",")
      url = AlmRequest.get_alm_url(params)

      body = File.read("#{fixture_path}alm_bad_response.json")

      stub_request(:get, "#{url}").to_return(:body => body, :status => 404)

      data = AlmRequest.get_data_for_articles(report.report_dois)

      data.size.should eq(0)

    end

    it "get ALM data for valid articles in the list" do
      report = Report.new
      report.save

      dois = [
        '10.1371/journal.pone.0064652',
        '10.1371/journal.pmed.AQSWEDR'
      ]

      report.add_all_dois(dois)

      params = {}
      params[:ids] = dois.join(",")
      url = AlmRequest.get_alm_url(params)

      body = File.read("#{fixture_path}alm_good_response2.json")

      stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

      data = AlmRequest.get_data_for_articles(report.report_dois)

      data.size.should eq(1)

      data['10.1371/journal.pone.0064652'][:plos_html].should eq(308)
      data['10.1371/journal.pone.0064652'][:plos_pdf].should eq(4)
      data['10.1371/journal.pone.0064652'][:plos_xml].should eq(7)
      data['10.1371/journal.pone.0064652'][:plos_total].should eq(319)

      data['10.1371/journal.pone.0064652'][:pmc_views].should eq(0)
      data['10.1371/journal.pone.0064652'][:pmc_pdf].should eq(1)
      data['10.1371/journal.pone.0064652'][:pmc_total].should eq(1)

      data['10.1371/journal.pone.0064652'][:total_usage].should eq(320)
      data['10.1371/journal.pone.0064652'][:viewed_data_present].should eq(true)

      data['10.1371/journal.pone.0064652'][:pmc_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:crossref_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:scopus_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:cited_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:citeulike].should eq(0)
      data['10.1371/journal.pone.0064652'][:mendeley].should eq(0)
      data['10.1371/journal.pone.0064652'][:saved_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:nature].should eq(0)
      data['10.1371/journal.pone.0064652'][:research_blogging].should eq(0)
      data['10.1371/journal.pone.0064652'][:scienceseeker].should eq(0)
      data['10.1371/journal.pone.0064652'][:facebook].should eq(0)
      data['10.1371/journal.pone.0064652'][:twitter].should eq(0)
      data['10.1371/journal.pone.0064652'][:wikipedia].should eq(0)
      data['10.1371/journal.pone.0064652'][:discussed_data_present].should eq(false)

    end

  end

  it "get ALM data for one article" do
    report = Report.new
    report.save

    dois = [
      '10.1371/journal.pmed.0020124'
    ]
    report.add_all_dois(dois)

    params = {}
    params[:ids] = dois.join(",")
    params[:info] = "history"
    params[:source] = "crossref,pubmed,scopus"
    url = AlmRequest.get_alm_url(params)

    body = File.read("#{fixture_path}alm_one_article_history.json")
    stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

    params = {}
    params[:ids] = dois.join(",")
    params[:info] = "event"
    params[:source] = "counter,pmc,citeulike,twitter,researchblogging,nature,scienceseeker,mendeley"
    url = AlmRequest.get_alm_url(params)    

    body = File.read("#{fixture_path}alm_one_article_event.json")
    stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

    data = AlmRequest.get_data_for_one_article(report.report_dois)

    data.size.should eq(1)

    data['10.1371/journal.pmed.0020124'][:crossref][:total].should eq(528)
    data['10.1371/journal.pmed.0020124'][:crossref].has_key?(:histories).should eq(true)

    data['10.1371/journal.pmed.0020124'][:pubmed][:total].should eq(208)
    data['10.1371/journal.pmed.0020124'][:pubmed].has_key?(:histories).should eq(true)

    data['10.1371/journal.pmed.0020124'][:scopus][:total].should eq(915)
    data['10.1371/journal.pmed.0020124'][:scopus].has_key?(:histories).should eq(true)

    data['10.1371/journal.pmed.0020124'][:counter][:total].should eq(677173)
    data['10.1371/journal.pmed.0020124'][:counter].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:pmc][:total].should eq(127280)
    data['10.1371/journal.pmed.0020124'][:pmc].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:citeulike][:total].should eq(364)
    data['10.1371/journal.pmed.0020124'][:citeulike].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:twitter][:total].should eq(640)
    data['10.1371/journal.pmed.0020124'][:twitter].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:researchblogging][:total].should eq(9)
    data['10.1371/journal.pmed.0020124'][:researchblogging].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:nature][:total].should eq(0)
    data['10.1371/journal.pmed.0020124'][:nature].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:scienceseeker][:total].should eq(1)
    data['10.1371/journal.pmed.0020124'][:scienceseeker].has_key?(:events).should eq(true)

    data['10.1371/journal.pmed.0020124'][:mendeley][:total].should eq(4064)
    data['10.1371/journal.pmed.0020124'][:mendeley].has_key?(:events).should eq(true)

  end

  context "get ALM data for visualization" do
    it "use Solr to get the data" do
      APP_CONFIG["alm_max_size_for_realtime"] = 1

      report = Report.new
      report.save

      dois = [
        '10.1371/journal.pone.0064652',
        '10.1371/journal.pmed.0020124'
      ]

      report.add_all_dois(dois)

      body = File.read("#{fixture_path}alm_solr_data_for_viz.json")
      url = "http://api.plos.org/search?facet=false&fl=id,alm_scopusCiteCount,alm_mendeleyCount,counter_total_all,alm_pmc_usage_total_all&fq=!article_type_facet:%22Issue%20Image%22&q=id:%2210.1371/journal.pone.0064652%22%20OR%20id:%2210.1371/journal.pmed.0020124%22&rows=2&wt=json"

      stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

      data = AlmRequest.get_data_for_viz(report.report_dois)

      data.size.should eq(2)

      data['10.1371/journal.pmed.0020124'][:total_usage].should eq(686164 + 127280)
      data['10.1371/journal.pmed.0020124'][:scopus_citations].should eq(915)
      data['10.1371/journal.pmed.0020124'][:mendeley].should eq(4064)

      data['10.1371/journal.pone.0064652'][:total_usage].should eq(439 + 1)
      data['10.1371/journal.pone.0064652'][:scopus_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:mendeley].should eq(0)
    end

    it "use ALM to get the data" do
      report = Report.new
      report.save

      dois = [
        '10.1371/journal.pone.0064652',
        '10.1371/journal.pmed.0020124'
      ]

      report.add_all_dois(dois)

      params = {}
      params[:ids] = dois.join(",")
      url = AlmRequest.get_alm_url(params)

      body = File.read("#{fixture_path}alm_good_response.json")

      stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

      data = AlmRequest.get_data_for_viz(report.report_dois)

      data.size.should eq(2)

      data['10.1371/journal.pone.0064652'][:plos_html].should eq(308)
      data['10.1371/journal.pone.0064652'][:plos_pdf].should eq(4)
      data['10.1371/journal.pone.0064652'][:plos_xml].should eq(7)
      data['10.1371/journal.pone.0064652'][:plos_total].should eq(319)

      data['10.1371/journal.pone.0064652'][:pmc_views].should eq(0)
      data['10.1371/journal.pone.0064652'][:pmc_pdf].should eq(1)
      data['10.1371/journal.pone.0064652'][:pmc_total].should eq(1)

      data['10.1371/journal.pone.0064652'][:total_usage].should eq(320)
      data['10.1371/journal.pone.0064652'][:viewed_data_present].should eq(true)

      data['10.1371/journal.pone.0064652'][:pmc_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:crossref_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:scopus_citations].should eq(0)
      data['10.1371/journal.pone.0064652'][:cited_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:citeulike].should eq(0)
      data['10.1371/journal.pone.0064652'][:mendeley].should eq(0)
      data['10.1371/journal.pone.0064652'][:saved_data_present].should eq(false)

      data['10.1371/journal.pone.0064652'][:nature].should eq(0)
      data['10.1371/journal.pone.0064652'][:research_blogging].should eq(0)
      data['10.1371/journal.pone.0064652'][:scienceseeker].should eq(0)
      data['10.1371/journal.pone.0064652'][:facebook].should eq(0)
      data['10.1371/journal.pone.0064652'][:twitter].should eq(0)
      data['10.1371/journal.pone.0064652'][:wikipedia].should eq(0)
      data['10.1371/journal.pone.0064652'][:discussed_data_present].should eq(false)


      data['10.1371/journal.pmed.0020124'][:plos_html].should eq(568181)
      data['10.1371/journal.pmed.0020124'][:plos_pdf].should eq(106120)
      data['10.1371/journal.pmed.0020124'][:plos_xml].should eq(2161)
      data['10.1371/journal.pmed.0020124'][:plos_total].should eq(676462)

      data['10.1371/journal.pmed.0020124'][:pmc_views].should eq(108674)
      data['10.1371/journal.pmed.0020124'][:pmc_pdf].should eq(18606)
      data['10.1371/journal.pmed.0020124'][:pmc_total].should eq(127280)

      data['10.1371/journal.pmed.0020124'][:total_usage].should eq(803742)
      data['10.1371/journal.pmed.0020124'][:viewed_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:pmc_citations].should eq(208)
      data['10.1371/journal.pmed.0020124'][:crossref_citations].should eq(528)
      data['10.1371/journal.pmed.0020124'][:scopus_citations].should eq(915)
      data['10.1371/journal.pmed.0020124'][:cited_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:citeulike].should eq(364)
      data['10.1371/journal.pmed.0020124'][:mendeley].should eq(4064)
      data['10.1371/journal.pmed.0020124'][:saved_data_present].should eq(true)

      data['10.1371/journal.pmed.0020124'][:nature].should eq(0)
      data['10.1371/journal.pmed.0020124'][:research_blogging].should eq(9)
      data['10.1371/journal.pmed.0020124'][:scienceseeker].should eq(1)
      data['10.1371/journal.pmed.0020124'][:facebook].should eq(4253)
      data['10.1371/journal.pmed.0020124'][:twitter].should eq(640)
      data['10.1371/journal.pmed.0020124'][:wikipedia].should eq(9)
      data['10.1371/journal.pmed.0020124'][:discussed_data_present].should eq(true)

    end

  end

end