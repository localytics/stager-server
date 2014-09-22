class RequestHandler

  attr_accessor :settings
  attr_accessor :request
  attr_accessor :container

  def parse_body
    @request.body.rewind
    begin
      yield @request.body.read
    rescue
      {}
    ensure
      @request.body.rewind
    end
  end

  def for_request(request)
    @request = request
    self
  end

  def with_response(response)
    @response = response
    self
  end

  def with_settings(settings)
    @settings = settings
    self
  end

  def with_container(container)
    @container = container
    self
  end

  def should_authenticate?
    false
  end

  def will_handle?
    raise NotImplementedError
  end 

  def handle
    raise NotImplementedError
  end
end
