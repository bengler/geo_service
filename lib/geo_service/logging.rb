module GeoService
  
  def self.logger
    @@logger ||= nil
  end
  
  def self.logger=(logger)
    @@logger = logger
  end
  
end