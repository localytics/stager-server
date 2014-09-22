class RoutingStrategy < RequestHandler

  attr_accessor :ports
  attr_accessor :event_type

  def will_handle?
    true
  end

  def with_ports(ports)
    @ports = ports
    self
  end

  def with_event_type(event_type)
    @event_type = event_type
    self
  end

  def kill_event_type?
    event_type == :kill
  end

  def clean
    File.delete target_path if File.exist? target_path
  end

  def write
    rendered = ERB.new(File.read(template_path), nil, '-').result(binding)
    File.open(target_path, 'wb') do |file|
      file.write(rendered)
    end
  end

end

