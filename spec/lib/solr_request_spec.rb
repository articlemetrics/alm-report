require 'spec_helper'
require 'solr_request'

describe SolrRequest do

  it "queries by pubmed ids" do

    pmids = [23717645, 16060722, 12345678901234567890]

    q = pmids.map {|pmid| "pmid:\"#{pmid}\""}.join(" OR ")

    url = "http://api.plos.org/search?q=#{URI::encode(q)}&fq=doc_type:full&fq=!article_type_facet:#{URI::encode("\"Issue Image\"")}&fl=id,publication_date,pmid&wt=json&facet=false&rows=#{pmids.size}"

    body = File.read("#{fixture_path}solr_pmid_validation.json")
    stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

    data = SolrRequest.query_by_pmids(pmids)
    data.size.should eq(2)

    data[23717645]["id"].should eq("10.1371/journal.pone.0064652")
    data[23717645]["pmid"].should eq("23717645")
    data[23717645]["publication_date"].should eq(Date.strptime("2013-05-23T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"))

    data[16060722]["id"].should eq("10.1371/journal.pmed.0020124")
    data[16060722]["pmid"].should eq("16060722")
    data[16060722]["publication_date"].should eq(Date.strptime("2005-08-30T00:00:00Zdddddddddd", "%Y-%m-%dT%H:%M:%SZ"))

  end

  it "validates dois" do
    dois = [
      '10.1371/journal.pone.0064652',
      '10.1371/journal.pmed.0020124',
      '10.1371/journal.test.s2dk421'
    ]

    q = dois.map { | doi | "id:\"#{doi}\"" }.join(" OR ")
    url = "http://api.plos.org/search?q=#{URI::encode(q)}&fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&fl=id&wt=json&facet=false&rows=#{dois.size}"
    body = File.read("#{fixture_path}solr_validate_dois.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    data = SolrRequest.validate_dois(dois)
    data.size.should eq(2)

    data["10.1371/journal.pone.0064652"]["id"].should eq("10.1371/journal.pone.0064652")
    data["10.1371/journal.pmed.0020124"]["id"].should eq("10.1371/journal.pmed.0020124")

  end

  it "gets data for articles" do

    dois = [
      '10.1371/journal.pone.0064652',
      '10.1371/journal.pmed.0020124',
      '10.1371/journal.test.s2dk421'
    ]

    q = dois.map { |doi| "id:\"#{doi}\"" }.join(" OR ")
    url = "http://api.plos.org/search?q=#{URI::encode(q)}&fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&fl=id,publication_date,title,cross_published_journal_name,author_display,article_type,affiliate,subject,pmid&wt=json&facet=false&rows=#{dois.size}"
    body = File.read("#{fixture_path}solr_get_data_for_articles.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    data = SolrRequest.get_data_for_articles(dois)

    data.size.should eq(2)

    data["10.1371/journal.pmed.0020124"]["id"].should eq("10.1371/journal.pmed.0020124")
    data["10.1371/journal.pmed.0020124"]["cross_published_journal_name"].should eq(["PLOS Medicine"])
    data["10.1371/journal.pmed.0020124"]["pmid"].should eq("16060722")
    data["10.1371/journal.pmed.0020124"]["subject"].should eq([
      "/Science policy/Research facilities/Research laboratories",
      "/Research and analysis methods/Research design",
      "/Research and analysis methods/Research design/Clinical research design",
      "/Medicine and health sciences/Clinical medicine/Clinical trials/Randomized controlled trials",
      "/Biology and life sciences/Genetics/Genomics/Genome analysis/Gene prediction",
      "/Research and analysis methods/Clinical trials/Randomized controlled trials",
      "/Biology and life sciences/Computational biology/Genome analysis/Gene prediction",
      "/Medicine and health sciences/Mental health and psychiatry/Schizophrenia",
      "/Biology and life sciences/Genetics/Genetics of disease",
      "/Medicine and health sciences/Epidemiology/Genetic epidemiology"
      ])
    data["10.1371/journal.pmed.0020124"]["publication_date"].should eq(Date.strptime("2005-08-30T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"))
    data["10.1371/journal.pmed.0020124"]["article_type"].should eq("Essay")
    data["10.1371/journal.pmed.0020124"]["author_display"].should eq(["John P. A. Ioannidis"])
    data["10.1371/journal.pmed.0020124"]["title"].should eq("Why Most Published Research Findings Are False")

  end

  it "gets journal name and journal key information" do

    url = "http://api.plos.org/search?facet=true&facet.field=cross_published_journal_key&facet.mincount=1&fq=!article_type_facet:%22Issue%20Image%22&q=*:*&rows=0&wt=json"
    body = File.read("#{fixture_path}solr_journal_keys.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    data = SolrRequest.get_journal_name_key

    data.size.should eq(8)
    journals = [
      {:journal_name=>"PLOS ONE", :journal_key=>"PLoSONE"},
      {:journal_name=>"PLOS Genetics", :journal_key=>"PLoSGenetics"},
      {:journal_name=>"PLOS Pathogens", :journal_key=>"PLoSPathogens"},
      {:journal_name=>"PLOS Computational Biology", :journal_key=>"PLoSCompBiol"},
      {:journal_name=>"PLOS Biology", :journal_key=>"PLoSBiology"},
      {:journal_name=>"PLOS Neglected Tropical Diseases", :journal_key=>"PLoSNTD"},
      {:journal_name=>"PLOS Medicine", :journal_key=>"PLoSMedicine"},
      {:journal_name=>"PLOS Collections", :journal_key=>"PLoSCollections"}
    ]
    data.should eq(journals)

  end

end