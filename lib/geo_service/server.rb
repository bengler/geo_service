require "mongrel"

module GeoService
  
  def self.run(options)
    server = Mongrel::HttpServer.new("0.0.0.0", options[:port])
    server.register("/selftest", SelfTestHandler.new)
    server.register("/reverse_lookup", ReverseLookupHandler.new)
    server.register("/stats", StatisticsHandler.new)
    server.run.join
  end
  
end
