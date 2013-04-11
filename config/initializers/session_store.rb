# Be sure to restart your server when you modify this file.

#AlmReport::Application.config.session_store :cookie_store, key: '_alm-report_session'
#AlmReport::Application.config.session_store :cache_store
Rails.application.config.session_store ActionDispatch::Session::CacheStore, :expire_after => 1.hour

