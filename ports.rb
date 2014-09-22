class Ports

  attr_accessor :min
  attr_accessor :max

  def initialize(options = {})
    @min = options[:min] || ENV['MIN_PORT'] || 3200
    @max = options[:max] || ENV['MAX_PORT'] || 3500
  end

  def next_port
    available.min.to_s
  end

  def range
    (min.to_i..max.to_i).to_a
  end

  def used
    ::Docker::Container.all.map do |c| 
      c.json["NetworkSettings"]["Ports"].to_a.map do |port|
        port[1].nil? ? [] : port[1].collect { |p| p["HostPort"].to_i || 0 }
      end
    end.flatten.uniq
  end

  def available
    range - used
  end

  def at_capacity?
    !next_port || next_port.empty? || !range.include?(next_port.to_i)
  end

end
