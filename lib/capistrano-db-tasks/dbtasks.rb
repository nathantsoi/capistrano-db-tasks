require File.expand_path("#{File.dirname(__FILE__)}/util")
require File.expand_path("#{File.dirname(__FILE__)}/database")
require File.expand_path("#{File.dirname(__FILE__)}/asset")

set :local_rails_env, ENV['RAILS_ENV'] || 'development' unless fetch(:local_rails_env)
set :rails_env, 'production' unless fetch(:rails_env)
set :db_local_clean, false unless fetch(:db_local_clean)
set :assets_dir, 'system' unless fetch(:assets_dir)
set :local_assets_dir, 'public' unless fetch(:local_assets_dir)
set :skip_data_sync_confirm, (ENV['SKIP_DATA_SYNC_CONFIRM'].to_s.downcase == 'true')
set :new_dump, (ENV['NEW_DUMP'].to_s.downcase == 'true')

namespace :db do
  namespace :remote do
    desc 'Synchronize your remote database using local database data'
    task :sync do
      on primary(:db) do
        if fetch(:skip_data_sync_confirm) || Util.prompt('Are you sure you want to REPLACE THE REMOTE DATABASE with local database')
          Database.local_to_remote(self)
        end
      end
    end
  end

  namespace :local do
    desc 'Synchronize your local database using remote database data'
    task :sync, :source do |t, args|
      on primary(:db) do
        unless args[:source].nil?
          raise 'Dumping and restoring to the same env would be unproductive' if args[:source] == fetch(:local_rails_env)
          within release_path do
            with rails_env: fetch(:rails_env) do
              execute :cap, "SKIP_DATA_SYNC_CONFIRM=true #{args[:source]} db:local:sync"
            end
          end
        else
          puts "Local database: #{Database::Local.new(self).database}, Remote database: #{Database::Remote.new(self).database}"
          if fetch(:skip_data_sync_confirm) || Util.prompt('Are you sure you want to erase your local database with server database')
            Database.remote_to_local(self)
          end
        end
      end
    end
  end

  desc 'Synchronize your local database using remote database data'
  task :pull, :source do |t, args|
    invoke "db:local:sync", args[:source]
  end

  desc 'Synchronize your remote database using local database data'
  task :push => "db:remote:sync"

  desc 'Backup the remote database, use -spath=some/path to set the backup directory'
  task :backup do
    on primary(:db) do
      backups_path = shared_path.join(fetch(:path, 'db/backups'))
      execute :mkdir, '-p', backups_path
      within backups_path do
        remote = Database::Remote.new(self)
        puts "Backing up database to #{remote.output_file}"
        remote.dump
      end
    end
  end

end

namespace :assets do
  namespace :remote do
    desc 'Synchronize your remote assets using local assets'
    task :sync do
      on roles(:app) do
        puts "Assets directories: #{fetch(:assets_dir)}"
        if fetch(:skip_data_sync_confirm) || Util.prompt("Are you sure you want to erase your server assets with local assets")
          Asset.local_to_remote(self)
        end
      end
    end
  end

  namespace :local do
    desc 'Synchronize your local assets using remote assets'
    task :sync do
      on roles(:app) do
        puts "Assets directories: #{fetch(:local_assets_dir)}"
        if fetch(:skip_data_sync_confirm) || Util.prompt("Are you sure you want to erase your local assets with server assets")
          Asset.remote_to_local(self)
        end
      end
    end
  end

  desc 'Synchronize your local assets using remote assets'
  task :pull => "assets:local:sync"

  desc 'Synchronize your remote assets using local assets'
  task :push => "assets:remote:sync"
end

namespace :app do
  namespace :remote do
    desc 'Synchronize your remote assets AND database using local assets and database'
    task :sync do
      if fetch(:skip_data_sync_confirm) || Util.prompt("Are you sure you want to REPLACE THE REMOTE DATABASE AND your remote assets with local database and assets(#{fetch(:assets_dir)})")
        Database.local_to_remote(self)
        Asset.local_to_remote(self)
      end
    end
  end

  namespace :local do
    desc 'Synchronize your local assets AND database using remote assets and database'
    task :sync do
      puts "Local database     : #{Database::Local.new(self).database}"
      puts "Assets directories : #{fetch(:local_assets_dir)}"
      if fetch(:skip_data_sync_confirm) || Util.prompt("Are you sure you want to erase your local database AND your local assets with server database and assets(#{fetch(:assets_dir)})")
        Database.remote_to_local(self)
        Asset.remote_to_local(self)
      end
    end
  end

  desc 'Synchronize your local assets AND database using remote assets and database'
  task :pull => "app:local:sync"

  desc 'Synchronize your remote assets AND database using local assets and database'
  task :push => "app:remote:sync"
end
