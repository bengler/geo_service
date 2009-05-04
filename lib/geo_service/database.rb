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
      @options = options
      connect
    end
    
    def query(sql, &block)
      try_database do
        entries = @connection.query(sql).entries
        if block
          return entries.each(&block)
        else
          return entries
        end
      end        
    end
    
    def connect
      @connection = PGconn.open(
        :host => @options["host"],
        :port => @options["port"],
        :dbname => @options["name"],
        :user => @options["user"],
        :password => @options["password"])
    end
    
    # Close the connection.
    def disconnect!
      @connection.close rescue nil
    end

    # Is this connection alive and ready for queries?
    def active?
      if @connection.respond_to?(:status)
        return @connection.status == PGconn::CONNECTION_OK
      else
        begin
          @connection.query('select 1')
        rescue
          return false
        else
          return true
        end
      end
    end

    # Close then reopen the connection.
    def reconnect!
      if @connection.respond_to?(:reset)
        @connection.reset
      else
        disconnect!
        connect
      end
    end

    protected
    
      def try_database(&block)
        begin
          return yield
        rescue PGError => e
          raise e if active?
          reconnect!
          return yield
        end
      end

  end
  
end
