# Application-wide settings and constants

require "#{Rails.root}/lib/solr_request.rb"

$RESULTS_PER_PAGE = 25

# Hack required to get this constant into SolrRequest, since it's in lib/
# and doesn't depend on this module.
SolrRequest.set_page_size($RESULTS_PER_PAGE)
