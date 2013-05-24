# Application-wide settings and constants

require "#{Rails.root}/lib/alm_request.rb"
require "#{Rails.root}/lib/geocode_request.rb"
require "#{Rails.root}/lib/solr_request.rb"
require "#{Rails.root}/lib/chart_data.rb"
require "#{Rails.root}/lib/ip_ranges.rb"

# Number of articles to display per page on the add-articles and preview-list
# pages.  (The results metrics page uses a different, smaller value.)
# This constant must be kept in sync with the constant of the same name in script.js.
$RESULTS_PER_PAGE = 25

# Hack required to get this constant into SolrRequest, since it's in lib/
# and doesn't depend on this module.
SolrRequest.set_page_size($RESULTS_PER_PAGE)

# Maximum number of articles that can be stored in a single report.
# This constant must be kept in sync with the constant of the same name in script.js.
$ARTICLE_LIMIT = 500
