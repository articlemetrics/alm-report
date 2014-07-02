source 'https://rubygems.org'

gem "puma"
gem "minitest", "~> 4.4.0"
gem "rails", "3.2.12"
gem "mysql2", "~> 0.3.11"
gem "dalli", "~> 2.6.2"
gem "countries", "~> 0.9.2"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem "sass-rails",   "~> 3.2.3"
  gem "coffee-rails", "~> 3.2.1"
  gem "therubyracer", "~> 0.11.4", :require => "v8"
  gem "uglifier", "~> 1.3.0"
  gem "jquery-rails", "~> 2.1.4"
end

group :test do
  gem "webmock", "~> 1.9.2"
end

group :test, :development do
  gem 'capistrano3-puma'
  gem "capistrano"
  gem "capistrano-rails"
  gem "rspec-rails", "~> 2.13.0"
end

