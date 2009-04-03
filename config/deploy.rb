set :application, "geo_service"
set :runner, "origo"
set :use_sudo, true
set :deploy_to, "/srv/origo/#{application}"

set :repository, "dev.bengler.no:/git/geo_service"
set :branch, "master"
set :scm, :git
set :scm_user, ENV["USER"]
set :deploy_via, :remote_cache
set :git_enable_submodules, 0

set :ssh_options, {:paranoid => false, :forward_agent => true}

role :app, "blixt.park.origo.no"

# Override deployment setup.
namespace :deploy do    
  desc "Setup application"
  task :setup, :roles => :app do
    paths = %W(
      #{deploy_to}
      #{deploy_to}/releases
      #{shared_path}
      #{shared_path}/pids
      #{shared_path}/tmp
      #{shared_path}/db
      #{shared_path}/config
    )
    run "umask 02 && mkdir -p #{paths.join(' ')}"
    run "if [ ! -d #{shared_path}/log ]; then ln -sfT /var/log/app/origo #{shared_path}/log; fi"
  end
end