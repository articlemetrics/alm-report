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
      url = "#{APP_CONFIG["alm_url"]}/?#{params.to_param}"

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
      url = "#{APP_CONFIG["alm_url"]}/?#{params.to_param}"

      body = File.read("#{fixture_path}alm_bad_response.json")

      stub_request(:get, "#{url}").to_return(:body => body, :status => 404)

      data = AlmRequest.get_data_for_articles(report.report_dois)

      data.size.should eq(0)

    end

    # TODO test looping logic for large list of articles

    # TODO test removing bad articles in a large list of articles

    # TODO test caching logic
  end

end