namespace :db do
  desc "Set up a pristine database"
  task :setup do
    system "createlang plpgsql geo_service"
    Dir.glob("config/postgis/*.sql").each do |file_name|
      system "psql -1 -q -d geo_service -f #{file_name}"
    end
  end
end
