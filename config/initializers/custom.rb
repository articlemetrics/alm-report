# Application-wide settings and constants

APP_CONFIG = YAML.load(ERB.new(File.read("#{Rails.root}/config/settings.yml")).result)[Rails.env]

require "#{Rails.root}/lib/alm_request.rb"
require "#{Rails.root}/lib/geocode_request.rb"
require "#{Rails.root}/lib/solr_request.rb"
require "#{Rails.root}/lib/chart_data.rb"
require "#{Rails.root}/lib/ip_ranges.rb"

# Maximum number of articles that can be stored in a single report.
# This constant must be kept in sync with the constant of the same name in script.js.
$ARTICLE_LIMIT = 500
