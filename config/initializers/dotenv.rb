# Check for required ENV variables, can be set in .env file
# ENV_VARS is hash of required ENV variables
env_vars = %w{ DB_USERNAME DB_HOST HOSTNAME MEMCACHE_SERVERS SITENAME SECRET_KEY_BASE MODE SEARCH SOLR_URL SOLR_MAX_DOIS ALM_URL ALM_API_KEY PER_PAGE METRICS_PER_PAGE WORK_LIMIT VIZ_LIMIT OMNIAUTH }
env_vars.each { |env| fail ArgumentError,  "ENV[#{env}] is not set" if ENV[env].blank? }
ENV_VARS = Hash[env_vars.map { |env| [env, ENV[env]] }]
