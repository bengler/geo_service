set :application, "geo_service"
set :runner, "origo"
set :use_sudo, true
set :deploy_to, "/srv/origo/#{application}"

set :repository, "git@github.com:origo/geo_service.git"
set :branch, "master"
set :scm, :git
set :scm_user, ENV["USER"]
set :deploy_via, :remote_cache
set :git_enable_submodules, false

set :ssh_options, {:paranoid => false, :forward_agent => true}

role :app,
  "blixt.park.origo.no",
  "pax.park.origo.no",
  "groggy.park.origo.no",
  "trogen.park.origo.no",
  "faktum.park.origo.no",
  "malm.park.origo.no"

namespace :deploy do
  desc "Deploy application."
  task :default do
    update
    restart
    cleanup
  end

  desc "Update application."
  task :update do
    update_code
    symlink
    prepare
  end

  desc "Setup application"
  task :setup, :roles => :app do
    paths = %W(
      #{deploy_to}
      #{deploy_to}/current
      #{shared_path}
      #{shared_path}/pids
      #{shared_path}/tmp
      #{shared_path}/db
      #{shared_path}/config
    )
    run "umask 02 && mkdir -p #{paths.join(' ')}"
    run "if [ ! -d #{shared_path}/log ]; then ln -sfT /var/log/app/origo #{shared_path}/log; fi"
    run <<-end
      if [ ! -d #{current_path}/.git ]; then \
        git clone #{repository} #{current_path} && chmod 2775 #{current_path};
      fi
    end
  end

  desc "Update the deployed code."
  task :update_code, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && git fetch --quiet origin && git reset --hard -q origin/master"
    bundler_install
  end
  
  task :bundler_install, :roles => :app do
    run "umask 002 && cd #{current_path} && sudo -u origo bundle install --deployment --without test:development"
  end  

  desc "Start the app"
  task :start, :roles => :app do
    run "sudo /etc/init.d/geo_service start"
  end

  desc "Stop the app"
  task :stop, :roles => :app do
    run "sudo /etc/init.d/geo_service stop"
  end

  desc "Restart the app"
  task :restart, :roles => :app do
    run "sudo /etc/init.d/geo_service stop; sudo /etc/init.d/geo_service start"
  end

  task :symlink do
    run "ln -sfT #{shared_path}/log #{current_path}/log"
    run "ln -sfT #{shared_path}/tmp #{current_path}/tmp"
  end

  task :prepare do
  end
end
