module PostGIS
  
  DEFAULT_SRID = 4326
  RADIUS_EARTH = 6372795.0
  DIAMETER_EARTH = RADIUS_EARTH*Math::PI*2
  RADIAN_FACTOR = Math::PI/180.0
    
  def self.squared_circle(center, radius)
    return PostGIS::Polygon.new([
      center.offset_meters(-radius, -radius),
      center.offset_meters(radius, -radius),
      center.offset_meters(radius, radius),
      center.offset_meters(-radius, radius),
      center.offset_meters(-radius, -radius)])
  end
  
  def self.rectangle(nw, se)
    return PostGIS::Polygon.new([
      center.offset_meters(nw.x, nw.y),
      center.offset_meters(se.x, nw.y),
      center.offset_meters(se.x, se.y),
      center.offset_meters(nw.x, se.y),
      center.offset_meters(nw.x, nw.y)])
  end
  
  # Point type
  class Point

    # x = longitude
    # y = latitude

    attr_reader :x, :y
    attr :srid, true
    
    def self.latlon(lat, lon, srid = PostGIS::DEFAULT_SRID)
      return new(lon, lat, srid)
    end

    def initialize(x, y, srid = PostGIS::DEFAULT_SRID)
      self.x, self.y, self.srid = x, y, srid
    end
    
    def offset_meters(easting, northing)
      new_latitude = northing.to_f/DIAMETER_EARTH*360.0 + self.y
      small_circle_radius = RADIUS_EARTH*Math.cos(new_latitude*RADIAN_FACTOR)
      meters_per_degree = small_circle_radius*Math::PI*2/360.0
      Point.new(
        easting/meters_per_degree + self.x,        
        new_latitude
      )
    end
    
    def ==(other)
      other.respond_to?(:x) && other.respond_to?(:y) && 
        self.x == other.x && self.y == other.y
    end
    
    # Gracefully lifted from 
    # http://www.whitehat.net.nz/articles/2007/01/24/great-circle-distance-in-ruby
    def self.haversine_distance(point_1, point_2)
      lon1 = point_1.x * RADIAN_FACTOR
      lat1 = point_1.y * RADIAN_FACTOR
      lon2 = point_2.x * RADIAN_FACTOR
      lat2 = point_2.y * RADIAN_FACTOR

      dlon = lon2 - lon1
      res = Math.atan2(
          Math.sqrt(((Math.cos(lat2) * Math.sin(dlon)) ** 2) + (((Math.cos(lat1) * \
          Math.sin(lat2)) - (Math.sin(lat1) * Math.cos(lat2) * Math.cos(dlon))) ** 2)),
          (Math.sin(lat1) * Math.sin(lat2)) + (Math.cos(lat1) * Math.cos(lat2) * Math.cos(dlon))
      ) * RADIUS_EARTH
      res
    end
    
    protected
    
      attr_writer :x, :y
    
  end
  
  # Composite
  class AbstractComposite
    
    attr_reader :elements
    attr :srid, true
    
    def initialize(elements, srid = PostGIS::DEFAULT_SRID)
      self.elements = []
      self.elements.concat(elements)
      self.elements.freeze
      self.srid = srid
    end
   
    def ==(other)
      return @elements == other.elements
    end
    
    # Returns the geometric centroid for this composite.
    def centroid
      # TODO - is this right?
      x = self.elements.inject(0.0) { |sum, p| p.x + sum } / self.elements.length
      y = self.elements.inject(0.0) { |sum, p| p.y + sum } / self.elements.length
      return Point.new(x, y)
    end

    protected
    
      attr_writer :elements
    
  end

  # Line type
  class LineString < AbstractComposite    
    def to_ewkb
      return Generator.generate_line_string(self, Writer.new).as_hex
    end
  end

  # Polygon
  class Polygon < AbstractComposite    
    def to_ewkb
      return Generator.generate_polygon(self, Writer.new).as_hex
    end
  end

  # Multipoint
  class MultiPoint < AbstractComposite    
    def to_ewkb
      return Generator.generate_multi_point(self, Writer.new).as_hex
    end
  end

  # Multipolygon
  class MultiPolygon < AbstractComposite    
    def to_ewkb
      return Generator.generate_multi_polygon(self, Writer.new).as_hex
    end
  end
  
  # Multi-line string
  class MultiLineString < AbstractComposite    
    def to_ewkb
      return Generator.generate_multi_line_string(self, Writer.new).as_hex
    end
  end
  
  # Extend class to support serialization.
  class ::NilClass
    def to_ewkb
      return nil
    end
  end

  # Extend class to support serialization.
  class Point
    def to_ewkb
      return Generator.generate_point(self, Writer.new).as_hex
    end
  end

end
