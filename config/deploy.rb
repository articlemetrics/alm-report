lock '3.2.1'

set :application, 'alm-report'
set :repo_url, 'git@github.com:PLOS/alm-report.git'
set :branch, 'master'
set :deploy_to, '/var/www/alm_report'
set :log_level, :info
set :linked_files, %w{ config/database.yml }
set :linked_dirs, %w{ bin log data tmp/pids tmp/sockets public/files }
set :keep_releases, 5

namespace :cfengine do
  task :disable do
    on roles :web do
      execute :touch, File.join(shared_path, 'deploying')
    end
  end

  task :enable do
    on roles :web do
      execute :rm, File.join(shared_path, 'deploying')
    end
  end
end

namespace :deploy do
  before :starting, "cfengine:disable"
  after :publishing, :restart
  after :finishing, "deploy:cleanup"
  after :finished, "cfengine:enable"
end

after :deploy, "cfengine:enable"
