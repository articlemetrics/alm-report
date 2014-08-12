set :stage, :development
set :repo_url, 'file:///var/www/alm-report/shared/'
set :branch, ENV["REVISION"] || ENV["BRANCH_NAME"] || "develop"
set :deploy_user, 'vagrant'
set :rails_env, :development

# install all gems into system
set :bundle_without, nil
set :bundle_binstubs, nil
set :bundle_path, nil
set :bundle_flags, '--system'

# don't precompile assets
set :assets_roles, []

server '33.33.33.55', roles: %w{web app db}

set :ssh_options, {
  user: "vagrant",
  keys: %w(~/.vagrant.d/insecure_private_key),
  auth_methods: %w(publickey)
}
