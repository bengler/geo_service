require "json"
require "mongrel"

module GeoService
  
  class AbstractHandler < Mongrel::HttpHandler
    
    def process(request, response)
      @request = request
      @params = Hash[*(@request.params["QUERY_STRING"] || "").
        split("&").map { |kv| kv.split("=")[0, 2] }.flatten]
      @response = response
      begin
        handle
      rescue Exception => e
        logger.error("Exception in HTTP handler: #{e.message}\n" <<
          e.backtrace.join("\n"))
        response.start(500) do |head, out|
          out.write("Internal error")
        end        
      end
    end

    protected
    
      def logger
        @logger ||= GeoService.logger
      end
      
  end
  
  class SelfTestHandler < AbstractHandler
    
    def handle
      @response.start do |head, out|
      end
    end
    
  end
  
  class StatisticsHandler < AbstractHandler
    
    def handle
      stats = GeoService.statistics
      @response.start do |head, out|
        head["Content-Type"] = "text/json"
        head["Cache-Control"] = "no-cache"
        out.write(stats.to_json)
      end
    end
    
  end

  class ReverseLookupHandler < AbstractHandler

    # Perform a reverse lookup. Query parameters:
    #
    # * +ll+ - a pair of coordinates as LATITUDE,LONGITUDE. Note that this follows the GIS
    #   convention of putting latitude first, even though it makes little sense.
    #
    def handle
      GeoService.with_statistics do
        lat, lon = (@params["ll"] || "").split(",").map { |s| s.to_f }
        unless lat and lon
          @response.start(500) do |head, out|
            out.write("Longitude and latitude expected.")
          end
          return
        end
        point = map_point(lon, lat)
        output = reverse_lookup(point)
        @response.start do |head, out|
          head["Content-Type"] = "text/json"
          head["Cache-Control"] = "no-cache"
          out.write(output.to_json)
        end
      end
    end
    
    private
    
      SRID_UTM33N = 25833
      
      COUNTY_NAMES_BY_ID = {
        "01" => "Østfold",
        "02" => "Akershus",
        "03" => "Oslo",
        "04" => "Hedmark",
        "05" => "Oppland",
        "06" => "Buskerud",
        "07" => "Vestfold",
        "08" => "Telemark",
        "09" => "Aust-Agder",
        "10" => "Vest-Agder",
        "11" => "Rogaland",
        "12" => "Hordaland",
        "14" => "Sogn og Fjordane",
        "15" => "Møre og Romsdal",
        "16" => "Sør-Trøndelag",
        "17" => "Nord-Trøndelag",
        "18" => "Nordland",
        "19" => "Troms",
        "20" => "Finnmark"
      }
      
      # Reverse lookup a point.
      def reverse_lookup(point)
        output = []
        sql = <<-end
          select navn, komm from fylker_pol
          where within('#{point.to_ewkb}', the_geom)
        end
        database = GeoService.database
        database.query(sql).each do |row|
          county_id = ("%04d" % row["komm"].to_i)[0, 2]
          output << {
            :municipality => row["navn"],
            :municipality_id => row["komm"],
            :county => COUNTY_NAMES_BY_ID[county_id],
            :county_id => county_id,
            :accuracy => 3  # As defined by Google Maps API
          }
        end
        output
      end
    
      # Convert a latitude, longitude point to the correct SRID.
      def map_point(lon, lat)
        lon, lat = project(lon, lat, "+proj=latlon +datum=WGS84 +to +proj=utm +zone=33")
        return PostGIS::Point.new(lon, lat, SRID_UTM33N)
      end
      
      # Project coordinates using Proj.
      def project(lon, lat, projection)
        IO.popen("echo '#{lon} #{lat}' | cs2cs -f %.9f #{projection}", "r") do |input|
          output = input.read
          lon, lat = output.split(" ")[0, 2].map { |v| v.to_f }
          return lon, lat
        end
      rescue Exception => e
        logger.error("Could not project coordinates: #{e}")
        return nil, nil
      end
            
  end
   
end
