require 'erb'
require 'sinatra/config_file'
require 'docker'
require './container'
require 'slugify'
require './ports'
require './request_handler'
require './request_handlers/github_request_handler'
require './authentication_strategy'
require './container_rotation_strategy'
require './routing_strategy'

class Stager < Sinatra::Base

  Dir["./request_handlers/*.rb"].each {|file| require file }
  Dir["./custom_request_handlers/*.rb"].each {|file| require file }

  register Sinatra::ConfigFile

  set :show_exceptions, false

  config_file 'config.yml'

  def ports
    @ports ||= Ports.new
  end

  def request_handlers_of_type(type)
    begin
      settings.send(type).map { |h| Object.const_get(h).new }.
        find_all { |h| h.kind_of? RequestHandler }
    rescue
      []
    end
  end

  def handle_request(type, container = nil)
    request_handlers_of_type(type).
      find_all { |h| h.for_request(request).with_settings(settings).with_container(container).will_handle? }.
      each { |h| h.handle }
  end

  def image_config(image)
    halt 400, 'Invalid Image Specified' unless image and settings.images[image] and 
      settings.images[image]['port'] and settings.images[image]['command']
    settings.images[image]
  end

  def container_environment
    env_hash = @image_config.clone
    env_hash.delete 'container_create_params'
    env_hash.delete 'container_start_params'
    env_hash.merge! @params
    env = env_hash.to_a.map { |e| "#{e[0]}=#{e[1]}" }
  end

  def container_by_name(name)
    ::Docker::Container.all.find { |c| c.json['Config']['Env'].find { |e| e == "container_name=#{name}" } }
  end

  def start_container
    expose_port = @image_config['port']
    env = container_environment
    container_params = { "Cmd" => @image_config['command'].split(/\s+/), "name" => @params[:container_name],
      "Image" => @image.id, "Env" => env, "ExposedPorts" => { "#{expose_port}/tcp" => {} } }
    container_params.merge!(settings.images[@params[:image_name]]['container_create_params'] || {})
    container = ::Docker::Container.create container_params
    container_start_params = { "PortBindings" => {"#{expose_port}/tcp" => [{'HostIp' => '0.0.0.0', 'HostPort' => ports.next_port}]} }
    container_start_params.merge!(settings.images[@params[:image_name]]['container_start_params'] || {})
    container.start container_start_params  
  end

  def authentication_strategy
    begin
      strategy = Object.const_get(settings.authentication_strategy).new
      return nil unless strategy.kind_of? AuthenticationStrategy
      strategy
    rescue
      nil
    end
  end

  def container_rotation_strategy
    begin
      strategy = Object.const_get(settings.container_rotation_strategy).new
      return nil unless strategy.kind_of? ContainerRotationStrategy
      strategy
    rescue
      nil
    end
  end

  def routing_strategy
    begin
      strategy = Object.const_get(settings.routing_strategy).new
      return nil unless strategy.kind_of? RoutingStrategy
      strategy
    rescue
      nil
    end
  end

  def update_routes(event_type, container=nil)
    if routing_strategy
      routing_strategy.for_request(request).with_settings(settings).with_container(container).with_ports(ports).with_event_type(event_type).handle
    else
      halt 500, 'Routing strategy is required'
    end
  end

  def authenticate(request)
    return if authentication_strategy && authentication_strategy.for_request(request).with_settings(settings).authenticates?
    halt 401, 'Unauthorized'
  end

  def process_launch(request)
    @params = request.params
    rotate_container_out if ports.at_capacity? && !container_by_name(@params[:container_name])
    @image_config = image_config @params[:image_name]
    image_name = @image_config['image_name'] || @params[:image_name]
    @image = ::Docker::Image.get image_name
    @host = request.host
    halt 400, 'No name specified for container' unless @params[:container_name]
    halt 400, "Invalid container name" if @params['container_name'] == 'default'

    process_kill(request) if container_by_name(@params[:container_name])
    ::Docker::Container.all(all: true).each { |c| c.delete unless c.json['State']['Running'] }
    container = start_container

    handle_request(:post_launch_handlers, container)

    update_routes(:launch, container)

    "#{@request.scheme}://#{@request.params[:container_name].slugify}.#{@request.env['HTTP_HOST']}"
  end


  def rotate_container_out
    oldest_container = ::Docker::Container.all.compact.
      find_all {|c| c.env_hash[:container_name] && !c.env_hash[:container_name].empty?}.
      sort_by {|c| c.json['Created']}.first
    container_to_rotate = (container_rotation_strategy &&
      container_rotation_strategy.with_settings(settings).container_to_rotate.kind_of?(::Docker::Container)) ?
        container_rotation_strategy.with_settings(settings).container_to_rotate : oldest_container
    kill_request = Rack::Request.new(request.env)
    kill_request.params.merge!(container_to_rotate.env_hash)
    process_kill(kill_request)
  end

  def process_kill(request)
    halt 400, "No name specified for container" unless request.params[:container_name] 
    halt 400, "Invaid container name" if request.params[:container_name] == 'default'

    container = container_by_name(request.params[:container_name])

    if container
      handle_request(:pre_kill_handlers, container)
      container.kill
    end

    update_routes(:kill, container)

    ::Docker::Container.all(all: true).each { |c| c.delete unless c.json['State']['Running'] }

    'ok'
  end

  def process_event
    handler_for_event = request_handlers_of_type(:event_listeners).
      find { |l| l.for_request(request).with_response(response).with_settings(settings).will_handle? }
    return unless handler_for_event
    result = handler_for_event.handle
    authenticate(request) if handler_for_event.should_authenticate?
    return result unless result.kind_of?(Hash) && (result.keys & [:action, :image_name, :container_name]).size == 3
    return result unless ['kill', 'launch'].include? result[:action]
    request.params.merge! result
    self.send("process_#{result[:action]}".to_sym, request)
  end

  before do
    request.params.default_proc = proc{|h, k| h.key?(k.to_s) ? h[k.to_s] : nil}
  end 

  get '/' do
    '<a target="_blank" href="http://www.funnyordie.com/videos/3ffc646c01/oh-hello-show-introduction-from-nick-kroll">Oh, hello</a>'
  end

  post '/launch' do
    authenticate request
    process_launch request
  end

  post '/kill' do
    authenticate request
    process_kill request
  end

  get '/event_receiver' do
    process_event
  end

  post '/event_receiver' do
    process_event
  end
end
