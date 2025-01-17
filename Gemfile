source "https://rubygems.org"

gem "rails", "4.1.8"
gem "mysql2"
gem "dalli"
gem "countries"
gem "dotenv"
gem "sass-rails"
gem "coffee-rails"
gem "therubyracer"
gem "uglifier"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "slim-rails"
gem "faraday"
gem "faraday_middleware"
gem 'bugsnag', '~> 2.8.6'

gem "devise", "~> 3.4.1"
gem "omniauth-persona"
gem "omniauth-cas", "~> 1.1.0"
gem 'omniauth-github', '~> 1.1.2'
gem "omniauth-orcid", "~> 0.6", :git => "https://github.com/mfenner/omniauth-orcid.git"
gem 'omniauth', '~> 1.2.2'

gem "ember-rails", "0.16.2"
gem "ember-source", "1.8.1"

group :development do
  gem "rubocop"
  gem "pry-rails"
  gem "better_errors"
  gem "binding_of_caller"
  gem 'capistrano', '~> 3.4.0'
  gem 'capistrano-passenger', '~> 0.0.5'
  gem 'capistrano-npm', '~> 1.0.0'
  gem "capistrano-rails", require: false
  gem "capistrano-bundler", require: false
end

group :test do
  gem "capybara-screenshot"
  gem "simplecov", require: false
  gem "timecop"
  gem "poltergeist"
  gem "capybara"
  gem "webmock"
  gem "codeclimate-test-reporter", require: false
  gem "vcr"
end

group :test, :development do
  gem "rspec-rails"
  gem "brakeman", :require => false
end
