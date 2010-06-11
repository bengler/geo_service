require "geo_service/postgis/geometry"
require "geo_service/postgis/tokenize"

module PostGIS
  
  # Parsing from EWKB to model.
  module Parser
    
    def self.parse(reader, header = true)
      reader = Reader.new(reader) if reader.respond_to?(:to_str)
      reader.read_header if header
      kind = reader.head_key
      case kind
        when Reader::KIND_POINT
          return parse_point(reader, false)
        when Reader::KIND_LINE_STRING
          return parse_line_string(reader, false)
        when Reader::KIND_POLYGON
          return parse_polygon(reader, false)
        when Reader::KIND_MULTI_POINT
          return parse_multi_point(reader, false)
        when Reader::KIND_MULTI_LINE_STRING
          return parse_multi_line_string(reader, false)
        when Reader::KIND_MULTI_POLYGON
          return parse_multi_polygon(reader, false)
        else
          raise ArgumentError, "Unrecognized geometry type"
      end
    end
    
    # Parses a point from a reader.
    def self.parse_point(reader, header = true)
      assert_header(Reader::KIND_POINT, reader.read_header) if header
      x, y = reader.read_doubles(2)
      return Point.new(x, y, reader.srid)
    end

    # Parses a line string from a reader.
    def self.parse_line_string(reader, header = true)
      assert_header(Reader::KIND_LINE_STRING, reader.read_header) if header
      points = []
      length = reader.read_uint32
      length.times do
        points << parse_point(reader, false)
      end
      return LineString.new(points, reader.srid)
    end

    # Parses a polygon from a reader.
    def self.parse_polygon(reader, header = true)
      assert_header(Reader::KIND_POLYGON, reader.read_header) if header
      element_type = reader.read_uint32
      points = []
      length = reader.read_uint32
      length.times do
        points << parse_point(reader, false)
      end
      return Polygon.new(points, reader.srid)
    end

    # Parses a multipoint from a reader.
    def self.parse_multi_point(reader, header = true)
      assert_header(Reader::KIND_MULTI_POINT, reader.read_header) if header
      points = []
      length = reader.read_uint32
      length.times do
        points << parse_point(reader, true)
      end
      return MultiPoint.new(points, reader.srid)
    end

    # Parses a multipolygon from a reader.
    def self.parse_multi_polygon(reader, header = true)
      assert_header(Reader::KIND_MULI_POLYGON, reader.read_header) if header
      points = []
      length = reader.read_uint32
      length.times do
        points << parse_polygon(reader, true)
      end
      return MultiPolygon.new(points, reader.srid)
    end

    # Parses a multi-line string from a reader.
    def self.parse_multi_line_string(reader, header = true)
      assert_header(Reader::KIND_MULTI_LINE_STRING, reader.read_header) if header
      strings = []
      length = reader.read_uint32
      length.times do
        strings << parse_line_string(reader, true)
      end
      return MultiLineString.new(strings, reader.srid)
    end

    protected
    
      def self.assert_header(expected, actual)
        if expected != actual
          raise ParseError, "Expected header #{expected.inspect}, got #{actual.inspect}"
        end
      end
    
  end
  
  # Generation of EWKB from model.
  module Generator
    
    # Writes the point to a writer.
    def self.generate_point(point, writer, header = true)
      writer.write_header(Reader::KIND_POINT, point.srid) if header
      writer.write_doubles([point.x, point.y])
      return writer
    end

    # Writes the linestring to a writer.
    def self.generate_line_string(line, writer, header = true)
      writer.write_header(Reader::KIND_LINE_STRING, line.srid) if header
      writer.write_uint32(Reader::KIND_POINT)
      writer.write_uint32(line.elements.length)
      line.elements.each do |element|
        generate_point(element, writer, false)
      end
      return writer
    end

    # Writes the polygon to a writer.
    def self.generate_polygon(polygon, writer, header = true)
      return writer if polygon.elements.length <= 2
      writer.write_header(Reader::KIND_POLYGON, polygon.srid) if header
      writer.write_uint32(Reader::KIND_POINT)
      writer.write_uint32(polygon.elements.length)
      polygon.elements.each do |element|
        generate_point(element, writer, false)
      end
      return writer
    end

    # Writes the multipolygon to a writer.
    def self.generate_multi_polygon(polygon, writer, header = true)
      writer.write_header(Reader::KIND_MULTI_POLYGON) if header
      # TODO: this is broken
      writer.write_uint32(1)
      writer.write_uint32(polygon.elements.length)
      polygon.elements.each do |element|
        generate_polygon(element, writer, false)
      end
      return writer
    end
    
    # Writes the multi-line string to a writer.
    def self.generate_multi_line_string(line_string, writer, header = true)
      writer.write_header(Reader::KIND_MULTI_LINE_STRING, line_string.srid) if header
      writer.write_uint32(1)
      writer.write_uint32(line_string.elements.length)
      line_string.elements.each do |element|
        generate_linestring(element, writer, false)
      end
      return writer
    end
    
    # Writes the multipolygon to a writer.
    def self.generate_multi_point(point, writer, header = true)
      writer.write_header(Reader::KIND_MULTI_POINT, point.srid) if header
      writer.write_uint32(point.elements.length)
      point.elements.each do |element|
        generate_point(element, writer, true)
      end
      return writer
    end
    
  end
  
  # Parse error exception
  class ParseError < RuntimeError
  end
  
end