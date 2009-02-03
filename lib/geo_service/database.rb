require "pg"

module GeoService
  
  def self.database
    @database
  end
  
  def self.database=(db)
    @database = db
  end
  
  class Database
    
    def initialize(options)
      @connection = PGconn.open(
        :host => options["host"],
        :port => options["port"],
        :dbname => options["name"],
        :user => options["user"],
        :password => options["password"])
    end
    
    def query(sql, &block)
      entries = @connection.query(sql).entries
      if block
        return entries.each(&block)
      else
        return entries
      end
    end
    
    def close
      @connection.finish
    end
    
  end
  
end
