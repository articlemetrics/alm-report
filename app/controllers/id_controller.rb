
require "csv"
require "set"

# Controller that handles the "Find Articles by DOI/PMID" page.
# TODO: better messaging when users hit the article limit.
class IdController < ApplicationController
  
  before_filter :set_tabs
  
  def index
    # doi/pmid page

    articleLimitReached?
  end
  
  def set_tabs
    @tab = :select_articles
    @title = "Find Articles by DOI/PMID"
    @errors = {}
    @max_doi_field = 8
  end
  
  
  # Checks that a given DOI appears to be a well-formed PLOS DOI.  Note that
  # this method only does a regex match; it does not query any backend to
  # determine if the corresponding article actually exists.
  # Returns nil if this is not a PLOS DOI, and something like
  # "10.1371/journal.pone.0049349" if it is (without the "info:doi/" prefix,
  # even if it is present on the input).
  def self.validate_doi(doi)
    
    # For simplicity we handle currents DOIs separately, since they don't have
    # as much internal structure as non-currents ones.
    %r|(info:)?(doi/)?(10\.1371/currents\.\S+)| =~ doi
    if !$~.nil?
      return $~[3]
    else
      %r|(info:)?(doi/)?(10\.1371/journal\.p[a-z]{3}\.\d{7})| =~ doi
      return $~.nil? ? nil : $~[3]
    end
  end
  
  
  # Performs validation of fields from the DOI/PMID form against SOLR.
  # Returns a list of matching solr docs, and populates the @errors field
  # if necessary as a side effect.
  def query_solr_for_ids(field_to_parsed_doi, field_to_parsed_pmid)
    dois = field_to_parsed_doi.values
    solr_docs = dois.length == 0 ? {} : SolrRequest.get_data_for_articles(dois)
    field_to_parsed_doi.each do |field, doi|
      if solr_docs[doi].nil?
        @errors[field.to_sym] = "This paper could not be found"
      end
    end

    pmid_docs = SolrRequest.query_by_pmids(field_to_parsed_pmid.values)
    field_to_parsed_pmid.each do |field, pmid|
      doc = pmid_docs[pmid]
      if doc.nil?
        @errors[field.to_sym] = "This paper could not be found"
      else
        solr_docs[doc["id"]] = doc
      end
    end
    solr_docs
  end
  
  
  def save
    # if the user is already at the article limit, do not let the user continue
    if articleLimitReached?
      render "index"
      return
    end

    # Ignore Errors is an option in the case when the user uploads a file
    # and it contains errors (that is, we get here via process_upload).
    if params[:commit] == "Ignore Errors"
      redirect_to "/preview-list"
      return
    end

    # This is totally not the rails way to do validation.  The rails way would
    # do it in the model.  Since we don't have a model for the DOIs that we
    # save to the session, we do it ourselves.  It's made more complicated by
    # the fact that we have two stages of validation, one with a regex and one
    # against solr (and for efficiency, we only want to send DOIs that have
    # passed the regex validation to solr).
    
    # I tried doing this the rails way, using Report and ReportDoi objects from
    # our model.  This resulted in a wasted day and much pain.  It's made
    # more complicated by the fact that the "Add More Fields" button adds more
    # DOI fields to the form with javascript, which I don't think rails can
    # deal with at all.
    field_to_parsed_doi = {}
    field_to_parsed_pmid = {}
    currents_dois = []
    params.each do |k, v|
      if k.start_with?("doi-pmid-") && !v.empty?
        
        # Assume for now that anything that looks like an int is a PMID.  We can't
        # use to_i here, since it will accept a value that only *starts* with
        # an integer.  So "10.1371/journal.pbio.0000001".to_i == 10.
        begin
          field_to_parsed_pmid[k] = Integer(v)
        rescue ArgumentError
          validated = IdController.validate_doi(v)
          if validated.nil?
            @errors[k.to_sym] = "This DOI/PMID is not a PLOS article"
          else
            
            # Don't attempt to validate currents DOIs against solr, since they
            # won't be there.
            %r|10\.1371/currents\.\S+| =~ validated
            if $~.nil?
              field_to_parsed_doi[k] = validated
            else
              currents_dois << validated
            end
          end
        end
        
        # This is to handle an edge case where the user has clicked on the
        # "Add More Fields" button on the form, and those new fields have
        # errors.  When we re-render the form we need to show all the fields.
        field_num = k[("doi-pmid-".length)..(k.length)].to_i
        @max_doi_field = field_num > @max_doi_field ? field_num : @max_doi_field
      end
    end
    
    # Now, for all the identifiers that passed regex validation, query against solr.
    solr_docs = query_solr_for_ids(field_to_parsed_doi, field_to_parsed_pmid)
    if @errors.length == 0
      
      # We don't have a publication date for currents articles, so just use
      # the order they were added to the form instead.
      currents_dois.each_with_index {|doi, i| @saved_dois[doi] = i}
      solr_docs.each {|_, doc| @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i}
      redirect_to "/preview-list"
    else
      render "index"
    end
  end
  
  
  def upload
    @title = "Upload File"

    articleLimitReached?
  end
  

  # Parses the uploaded DOI file, which will be something that looks like
  # a CSV with only one entry/row.
  def parse_file(contents)
    results = []
    CSV.parse(contents.read) do |row|
      test = row[0].downcase

      # Handle the header row.
      if test != "doi" && test != '"doi"'
        results << row[0]
      end
    end
    results
  end
  
  
  def process_upload
    # if the user is already at the article limit, do not let the user continue
    if articleLimitReached?
      render "upload"
      return
    end

    if params[:"upload-file-field"].nil?
      @file_absent = true
      render "upload"
      return
    end
    ids = parse_file(params[:"upload-file-field"])
    valid_dois = []
    valid_pmids = []
    
    # In order to re-use parts of the DOI input form for upload errors, we create
    # form field names for each error.
    error_index = 1
    add_error = lambda { |id, error_message|
      error_field = "doi-pmid-#{error_index}".intern
      error_index += 1
      @errors[error_field] = error_message
      params[error_field] = id
    }
    
    ids.each do |id|
      id = id.strip
      if id.length > 0
        begin
          valid_pmids << Integer(id)
        rescue ArgumentError
          validated = IdController.validate_doi(id)
          if validated.nil?
            add_error.call(id, "This DOI/PMID is not a PLOS article")
          else
            valid_dois << validated
          end
        end
      end
    end

    solr_docs = SolrRequest.get_data_for_articles(valid_dois)
    valid_dois.each do |doi|
      doc = solr_docs[doi]
      if doc.nil?
        add_error.call(doi, "This paper could not be found")
      else
        @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i
      end
    end
    
    pmid_docs = SolrRequest.query_by_pmids(valid_pmids)
    valid_pmids.each do |pmid|
      doc = pmid_docs[pmid]
      if doc.nil?
        add_error.call(pmid, "This paper could not be found")
      else
        @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i
      end
    end

    if @errors.length > 0
      @num_valid_dois = @saved_dois.length
      render "fix_errors"
    else
      redirect_to "/preview-list"
    end
  end
  
end
