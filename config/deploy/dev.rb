set :rails_env, 'dev'
server 'sfo-dev-alm01.int.plos.org', user: 'alm_with_capistrano', roles: %w[web app db]
