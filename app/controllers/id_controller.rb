
require "set"

# Controller that handles the "Find Articles by DOI/PMID" page.
class IdController < ApplicationController
  
  before_filter :set_tabs
  
  
  def set_tabs
    @tab = :select_articles
    @title = "Find Articles by DOI/PMID"
    @errors = Set.new
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
        %r|(info:)?(doi/)?(10\.1371/journal\.p[a-z]{3}\.\d{7})| =~ v
        if $~.nil?
          @errors.add(k.to_sym)
        else
          field_to_parsed_doi[k] = $~[3]
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
      saved = session[:dois]
      if saved.nil?
        saved = {}
      end
      solr_docs.each {|_, doc| saved[doc["id"]] = doc["publication_date"].strftime("%s").to_i}
      session[:dois] = saved
      redirect_to "/preview-list"
    else
      render "index"
    end
  end
  
end
