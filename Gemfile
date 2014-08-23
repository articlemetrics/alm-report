source 'https://rubygems.org'

gem "rails", "3.2.17"
gem "mysql2", "~> 0.3.13"
gem "dalli", "~> 2.7.0"
gem "countries", "~> 0.9.2"

gem "sass-rails",   "~> 3.2.5"
gem "coffee-rails", "~> 3.2.2"
gem "therubyracer", "~> 0.12.0", :require => "v8"
gem "uglifier", "~> 2.4.0"
gem "jquery-rails", "~> 3.1.0"
gem 'jquery-ui-rails', '~> 5.0.0'

group :development do
  gem 'capistrano-rails', '~> 1.1.1', require: false
  gem 'capistrano-bundler', '~> 1.1.2', require: false
end

group :test do
  gem "webmock", "~> 1.17.2"
  gem "minitest", "~> 4.4.0"
  gem "codeclimate-test-reporter", require: false
end

group :test, :development do
  gem "rspec-rails", "~> 2.14.0"
  gem "brakeman", :require => false
end
