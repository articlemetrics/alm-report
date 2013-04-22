# Application-wide settings and constants

require "#{Rails.root}/lib/alm_request.rb"
require "#{Rails.root}/lib/solr_request.rb"

# Number of articles to display per page on the add-articles and preview-list
# pages.  (The results metrics page uses a different, smaller value.)
# This constant must be kept in sync with the constant of the same name in script.js.
$RESULTS_PER_PAGE = 25

# Maximum number of articles that can be stored in a single report.
# This constant must be kept in sync with the constant of the same name in script.js.
$ARTICLE_LIMIT = 500
