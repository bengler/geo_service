require "benchmark"

module GeoService
  
  def self.statistics
    synchronize {
      @statistics ||= {}
      return @statistics.clone
    }
  end

  def self.with_statistics(&block)
    result = nil
    time = Benchmark.realtime { result = yield }
    update_statistics(1, time)
    return result
  end
  
  def self.update_statistics(count, elapsed_time)
    synchronize {
      s = @statistics ||= {:count => 0, :elapsed_time => 0, :avg_time => 0}
      s[:count] += 1
      s[:elapsed_time] += elapsed_time
      s[:avg_time] += s[:elapsed_time] / s[:count].to_f
    }
  end
  
  private
  
    def self.synchronize(&block)
      mutex = @mutex ||= Mutex.new
      mutex.synchronize(&block)
    end
  
end
