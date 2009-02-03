# From IvyGIS by Robert S. Thau. Copyright 2006, Japan Spatial Information 
# Technology, Inc.
#
# Distributed without warranty under the terms of the GNU General Public
# License, version 2.  

module PostGIS

  # Reads the OpenGIS EKWB format.  
  class Reader

    attr_reader :raw_bytes, :pos, :big_endian, :head_key, :fmt_code, :srid, :has_z, :has_m, :has_bbox

    # Head keys
    KIND_POINT = 1
    KIND_LINE_STRING = 2
    KIND_POLYGON = 3
    KIND_MULTI_POINT = 4
    KIND_MULTI_LINE_STRING = 5
    KIND_MULTI_POLYGON = 6
 
    def initialize(bytes, raw = nil)
      raw = (bytes.length % 2 == 1) || !bytes.index(/[^0-9a-f]/) if raw.nil?
      @raw_bytes = raw ? bytes : [bytes].pack('H*')
      @pos = 0
      @srid = -1
    end
 
    def reset
      @pos = 0
    end
 
    def read_header
      endianness = @raw_bytes[@pos]
      unless [0, 1].include?(endianness)
        raise BadFormatError, "Bad endianness flag byte: 0 or 1 expected, got #{endianness}"
      end
 
      @big_endian = read_byte == 0
      header    = self.read_uint32
      @head_key  = (header & 0xff)
      @has_z     = ((header & 0x80000000) != 0)
      @has_m     = ((header & 0x40000000) != 0)
      @has_bbox  = ((header & 0x10000000) != 0)
 
      if (![KIND_POINT, KIND_LINE_STRING, KIND_MULTI_POINT, KIND_POLYGON, KIND_MULTI_LINE_STRING, 
        KIND_MULTI_POLYGON].include?(@head_key))
        raise BadFormatError, "Unknown geometry type code #{@head_key}"
      end
 
      @srid = -1
      if (header & 0x20000000) != 0
        @srid = read_uint32
      end
 
      if @has_z || @has_m
        raise BadFormatError, "Multidimensional data not supported"
      end
 
      if @has_bbox
        raise BadFormatError, "Data with bounding boxes not supported"
      end
      
      @head_key
    end
    
    def read_byte
      @pos += 1
      raw_bytes[@pos - 1]
    end
 
    def read_uint32
      if (@pos + 4 > @raw_bytes.length)
        raise BadFormatError, "overrun"
      end
      @pos += 4
      return @raw_bytes[@pos-4,@pos].unpack(@big_endian? 'N' : 'V')[0]
    end
 
    def read_doubles(n)
      if (@pos + n * 8 > @raw_bytes.length)
        raise BadFormatError, "overrun"
      end
      @pos += n * 8
      return @raw_bytes[@pos - n*8,@pos].unpack((@big_endian? 'G' : 'E') * n)
    end
  end
 
  # Writes the OpenGIS EKWB format.  
  class Writer
 
    attr_reader :buffer
    
    def initialize
      @buffer = ''
    end
 
    def as_hex
      return nil if @buffer.empty?
      @buffer.unpack('H*')[0].upcase
    end
 
    def write_header(type_code, srid = -1)
      write_byte(1)
      flag = type_code
      flag |= 0x20000000 if srid and srid != -1
      write_uint32(flag)
      if srid and srid != -1
        write_uint32(srid)
      end
    end
    
    def write_byte(b)
      @buffer << b
    end
 
    def write_uint32(n)
      @buffer << [n].pack('V')
    end
 
    def write_doubles(d)
      @buffer << d.pack('E' * d.length)
    end
    
  end
  
  class BadFormatError < RuntimeError
  end
   
end
