# Be sure to restart your server when you modify this file.

# use memcached for session store
Rails.application.config.session_store ActionDispatch::Session::CacheStore, :expire_after => 1.hour

