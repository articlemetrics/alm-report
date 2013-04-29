
require "set"

# Controller that handles the "Find Articles by DOI/PMID" page.
# TODO: better messaging when users hit the article limit.
class IdController < ApplicationController
  
  before_filter :set_tabs
  
  
  def set_tabs
    @tab = :select_articles
    @title = "Find Articles by DOI/PMID"
    @errors = Set.new
  end
  
  
  # Checks that a given DOI appears to be a well-formed PLOS DOI.  Note that
  # this method only does a regex match; it does not query any backend to
  # determine if the corresponding article actually exists.
  # Returns nil if this is not a PLOS DOI, and something like
  # "10.1371/journal.pone.0049349" if it is (without the "info:doi/" prefix,
  # even if it is present on the input).
  def self.validate_doi(doi)
    %r|(info:)?(doi/)?(10\.1371/journal\.p[a-z]{3}\.\d{7})| =~ doi
    return $~.nil? ? nil : $~[3]
  end
  
  
  def save

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
    params.each do |k, v|
      if k.start_with?("doi-pmid-") && !v.empty?
        validated = IdController.validate_doi(v)
        if validated.nil?
          @errors.add(k.to_sym)
        else
          field_to_parsed_doi[k] = validated
        end
      end
    end
    
    # Now, for all the DOIs that passed regex validation, query against solr.
    solr_docs = SolrRequest.get_data_for_articles(field_to_parsed_doi.values)
    field_to_parsed_doi.each do |field, doi|
      if solr_docs[doi].nil?
        @errors.add(field.to_sym)
      end
    end

    if @errors.length == 0
      solr_docs.each {|_, doc| @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i}
      redirect_to "/preview-list"
    else
      render "index"
    end
  end
  
  
  def upload
    @title = "Upload File"
  end
  
  
  # TODO: figure out what the expected format of this file is!  I am assuming
  # for now that it's just one DOI per line.
  def parse_file(contents)
    return contents.split("\n")
  end
  
  
  def process_upload
    dois = parse_file(params[:"upload-file-field"].read)
    @errors = []
    valid_dois = []
    dois.each do |doi|
      validated = IdController.validate_doi(doi)
      if validated.nil?
        @errors << doi
      else
        valid_dois << validated
      end
    end

    solr_docs = SolrRequest.get_data_for_articles(valid_dois)
    valid_dois.each do |doi|
      doc = solr_docs[doi]
      if doc.nil?
        @errors << doi
      else
        @saved_dois[doc["id"]] = doc["publication_date"].strftime("%s").to_i
      end
    end

    if @errors.length > 0
      @num_valid_dois = @saved_dois.length
      
      # TODO: this only renders a mockup right now; not yet functional.
      render "fix_errors"
    else
      redirect_to "/preview-list"
    end
  end
  
end
