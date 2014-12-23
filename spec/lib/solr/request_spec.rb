require "rails_helper"

describe Solr::Request do
  it "queries by pubmed ids" do

    pmids = [23717645, 16060722, 12345678901234567890]

    q = pmids.map {|pmid| "pmid:\"#{pmid}\""}.join(" OR ")

    url = "http://api.plos.org/search?q=#{URI::encode(q)}&fq=doc_type:full&fq=!article_type_facet:#{URI::encode("\"Issue Image\"")}&fl=id,publication_date,pmid&wt=json&facet=false&rows=#{pmids.size}"

    body = File.read("#{fixture_path}solr_pmid_validation.json")
    stub_request(:get, "#{url}").to_return(:body => body, :status => 200)

    data = Solr::Request.query_by_pmids(pmids)
    data.size.should eq(2)

    data[23717645].id.should eq("10.1371/journal.pone.0064652")
    data[23717645].pmid.should eq("23717645")
    data[23717645].publication_date.should eq(Date.strptime("2013-05-23T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"))

    data[16060722].id.should eq("10.1371/journal.pmed.0020124")
    data[16060722].pmid.should eq("16060722")
    data[16060722].publication_date.should eq(Date.strptime("2005-08-30T00:00:00Zdddddddddd", "%Y-%m-%dT%H:%M:%SZ"))
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

    data = Solr::Request.validate_dois(dois)
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
    url = "http://api.plos.org/search?q=#{URI::encode(q)}&fq=doc_type:full" \
        "&fq=!article_type_facet:%22Issue%20Image%22" \
        "&fl=id,pmid,publication_date,received_date,accepted_date,title," \
        "cross_published_journal_name,author_display,editor_display,article_type,affiliate," \
        "subject,financial_disclosure&wt=json&facet=false&rows=#{dois.size}"
    body = File.read("#{fixture_path}solr_get_data_for_articles.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    data = Solr::Request.get_data_for_articles(dois)

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

    url = "http://api.plos.org/search?facet=true&facet.field=cross_published_journal_key&facet.mincount=1&fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&q=*:*&rows=0&wt=json"
    body = File.read("#{fixture_path}solr_journal_keys.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    data = Solr::Request.get_journals

    data.size.should eq(8)

    journals = {
      "PLoSBiology" => "PLOS Biology",
      "PLoSCollections" => "PLOS Collections",
      "PLoSCompBiol" => "PLOS Computational Biology",
      "PLoSGenetics" => "PLOS Genetics",
      "PLoSMedicine" => "PLOS Medicine",
      "PLoSNTD" => "PLOS Neglected Tropical Diseases",
      "PLoSONE" => "PLOS ONE",
      "PLoSPathogens" => "PLOS Pathogens"
    }
    data.should eq(journals)
  end

  it "returns processed publication_date" do
    body = File.read("#{fixture_path}simple_search_result.json")
    stub_request(:get, /api.plos.org/).to_return(body: body)

    params = {
      :everything =>"word",
      :publication_days_ago => "0",
      :datepicker1 => "05-07-2014",
      :datepicker2 => "10-31-2014"
    }

    q = Solr::Request.new(params)
    results, total_results, metadata = q.query
    metadata[:publication_date][0].should eq(Date.strptime("05-07-2014", "%m-%d-%Y"))
    metadata[:publication_date][1].should eq(DateTime.strptime("10-31-2014 23:59:59", "%m-%d-%Y %H:%M:%S"))
  end

  it "query for articles using simple search" do

    url = "http://api.plos.org/search?q=affiliate:%22University%20of%20California%22%20AND%20" \
        "author:Garmay%20AND%20everything:word%20AND%20subject:%22Gene%20regulation%22&" \
        "fq=doc_type:full&fq=!article_type_facet:%22Issue%20Image%22&" \
        "fl=id,pmid,publication_date,received_date,accepted_date,title," \
        "cross_published_journal_name,author_display,editor_display,article_type,affiliate," \
        "subject,financial_disclosure&wt=json&facet=false&rows=25&hl=false"
    body = File.read("#{fixture_path}simple_search_result.json")
    stub_request(:get, url).to_return(:body => body, :status => 200)

    params = {
      :everything=>"word",
      :author=>"Garmay",
      :author_country=>"",
      :institution=>"University of California",
      :subject=>"Gene regulation",
      :filters=>["All Journals"],
      :financial_disclosure=>""
    }

    q = Solr::Request.new(params, nil)
    results, total_results = q.query

    results[0].data.should eq({
      "id" => "10.1371/journal.pone.0006901",
      "cross_published_journal_name" => ["PLOS ONE"],
      "pmid" => "19730735",
      "subject" => [
        "/Research and analysis methods/Molecular biology techniques/Sequencing techniques/Sequence analysis",
        "/Biology and life sciences/Genetics/Genomics/Genome analysis/Genomic databases",
        "/Computer and information sciences/Information technology/Databases/Genomic databases",
        "/Biology and life sciences/Biochemistry/DNA/DNA sequences",
        "/Biology and life sciences/Biochemistry/Proteins/DNA-binding proteins/Transcription factors",
        "/Computer and information sciences/Information technology/Databases/Database and informatics methods/Database searching/Sequence similarity searching",
        "/Research and analysis methods/Database and informatics methods/Database searching/Sequence similarity searching",
        "/Biology and life sciences/Genetics/Genomics/Animal genomics/Invertebrate genomics",
        "/Biology and life sciences/Genetics/Gene expression/Gene regulation/Transcription factors",
        "/Biology and life sciences/Computational biology/Genome analysis/Genomic databases",
        "/Biology and life sciences/Biochemistry/Proteins/Regulatory proteins/Transcription factors",
        "/Research and analysis methods/Molecular biology techniques/Sequencing techniques/Sequence analysis/Sequence motif analysis",
        "/Biology and life sciences/Genetics/Gene expression/Gene regulation", "/Biology and life sciences/Genetics/DNA/DNA sequences"
      ],
      "publication_date" => Date.strptime("2009-09-04T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"),
      "article_type" => "Research Article",
      "author_display" => ["Garmay Leung", "Michael B. Eisen"],
      "affiliate" => [
        "University of California Berkeley and University of California San Francisco Joint Graduate Group in Bioengineering, University of California, Berkeley, California, United States of America",
        "Department of Molecular and Cell Biology, University of California, Berkeley, California, United States of America",
        "Howard Hughes Medical Institute, University of California, Berkeley, California, United States of America"
      ],
      "title" => "Identifying Cis-Regulatory Sequences by Word Profile Similarity"
    })
    total_results.should eq(1)
  end

  it "can use a custom field list (fl)" do
    url = "http://api.plos.org/search?facet=false&fl=id,pmid,publication_date" \
          "&fq=doc_type:full&fq=!article_type_facet:%22Issue%20" \
          "Image%22&hl=false&q=everything:biology&rows=25&wt=json"

    fl = "id,pmid,publication_date"

    fixture = File.open("#{fixture_path}solr_custom_field_list.raw")
    stub_request(:get, url).to_return(fixture)

    request = Solr::Request.new({everything: 'biology'}, fl)
    data = request.query

    # We should get the requested fields in the result
    data[0].first.data.keys.should eq(fl.split(','))
  end
end
