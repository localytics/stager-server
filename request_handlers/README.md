#Request Handlers

Request handlers are simple class definitions with a maximum of two methods required, making them very easy to create. Depending on the type of request handler you are creating, different instance variables are made available to those methods for interacting with the Stager instance and current request.

All .rb files in the /request_handlers and /custom_request_handlers directories are autoloaded and made available (the latter directory is ignored by git) to be referenced by class name in config.yml

##authentication_strategy

Authentication strategies require only one method be defined, the #authenticates? method. When it returns true, access is granted. When it returns false, a 401 is returned.

They must inherit from the AuthenticationStrategy class.

The authentication strategy has access to two instance variables:

*  @request - the Rack::Request which represents the current request
*  @settings - the settings object that represents the config.yml parsed by [Sinatra::ConfigFile](http://www.sinatrarb.com/contrib/config_file.html)

Example:

The authentication strategy below checks the configured 'stager_pass' against the pw request param and grants access if they match:

```ruby
class StupidAuthentication < AuthenticationStrategy

  def authenticates?
    @request.params[:pw] == @settings.stager_pass
  end
end
```

To use this strategy, you would save this in either request handler directory and update config.yml as follows

```yaml
authentication_strategy: 'StupidAuthentication'
```

When adding authentication strategies, it is often useful to [add an auth strategy to the Stager cli gem](https://github.com/localytics/stager-client/blob/master/README.md#adding-auth-strategies) which corresponds to the new authentication strategy, making use of the authentication strategy easier when interacting with Stager via the API.

##container_rotation_strategy

Container rotation strategies require only one method be defined, the #container\_to\_rotate method. It should return an instance of ::Docker::Container representing the running container to be killed when processing a launch request and all ports allocated to Stager are in use. 

They must inherit from the ContainerRotationStrategy class.

The container rotation strategy has access to one instance variable:

*  @settings - the settings object that represents the config.yml parsed by [Sinatra::ConfigFile](http://www.sinatrarb.com/contrib/config_file.html)

Example: See evergreen\_exceptions\_container\_rotation\_strategy.rb above

To use this strategy, you would update config.yml as follows

```yaml
authentication_strategy: 'EvergreenExceptionContainerRotationStrategy'
evergreen_containers:
  - 'evergreen_container_name_1'
  - 'evergreen_container_name_etc'
```

##post_launch_handlers and pre_kill_handlers

These handlers are fired after container launch and before container kill respectively. They both must implement the #will_handle? and #handle methods. If #will_handle? returns true, the #handle method will be called. Multiple handlers for each of these types can be called for one request.

They must inherit from the RequestHandler class.

These handlers have access to the following instance variables:

*  @request - the Rack::Request which represents the current request
*  @settings - the settings object that represents the config.yml parsed by [Sinatra::ConfigFile](http://www.sinatrarb.com/contrib/config_file.html)
*  @container - the [Docker::Container](http://rubydoc.info/gems/docker-api/1.10.4/Docker/Container) object that was launched or is being killed, augmented with the [env_hash method](../container.rb)

The following handler will output "Killing a foo container" or "Launching a foo container" when killing or launching a container with a name containing the substring foo, respectively:

```ruby
class PutsOnFooLaunchOrKill < RequestHandler

  def will_handle?
    # only handle if container name has "foo" in it
    @container.env_hash[:container_name].include? "foo"
  end
  
  def handle
    puts "#{@request.env['REQUEST_URI'].gsub(/^\//, '').capitalize}ing a foo container"
  end
end
```

To use this handler, you would save this in either request handler directory and update config.yml as follows

```yaml
post_launch_request_handlers:
  - 'PutsOnFooLaunchOrKill'
pre_kill_request_handlers:
  - 'PutsOnFooLaunchOrKill'
```

##event_listeners

These handlers are fired when the /event_receiver endpoint receives a post request. Like the post_launch_handlers and pre_kill_handlers, event_listeners must also implement the #will_handle? and #handle methods. The first event handler whose #will_handle? method returns true will be the only one to execute for a specific request.

Additionally, these handlers can define a #should_authenticate? method. If this method returns true, the configured authentication_strategy will be used to authenticate the request before the #handle method is called. Note that it is important to authenticate requests sent to this endpoint, if not using the configured authentication strategy, then by some other means.

They must inherit from the RequestHandler class.

The event handler has access to the following instance variables:

*  @request - the Rack::Request which represents the current request
*  @response - the Sinatra::Response which will be sent once the request is complete
*  @settings - the settings object that represents the config.yml parsed by [Sinatra::ConfigFile](http://www.sinatrarb.com/contrib/config_file.html)

The event handler can trigger a container launch or kill by returning a hash with the following properties:

*  Keys of :action, :image_name, and :container_name
*  A value for key :action of either 'launch' or 'kill'

When this condition is met, any additional hash properties are passed to the launch/kill request as well.

The following event listener will execute when the action parameter is set to 'container_status', toggle the state of a named container when the 'toggle' param is passed, and report the status otherwise.

```ruby
class ContainerStatus < RequestHandler

  def will_handle?
    @request.params[:action] == 'container_status' &&
      ([:image_name, :container_name] & @request.params.keys).size == 2
  end
  
  def container
    @container ||= ::Docker::Container.all.
      find do |c| 
        c.env_hash[:image_name] == @request.params[:image_name] &&
        c.env_hash[:container_name] == @request.params[:container_name]
      end
  end
  
  def toggle_params
    params = {
      image_name: @request.params[:image_name]
      container_name: @request.params[:container_name]
    }
    params[:action] = container ? 'kill' : 'launch'
    params
  end
  
  def handle
    return toggle_params if @request.params[:toggle]
    return container ? 'Container is running' : 'Container is not running'
  end
end
``` 

Note: the /launch and /kill endpoints are idempotent, this example is simply to illustrate all possible return paths for an event listener.

To use this handler, you would save this in either request handler directory and update config.yml as follows

```yaml
event_listeners:
  - 'ContainerStatus'
```

##Documenting Request Handlers

New request handlers are eagerly welcomed, and in order to maintain consistency and usability, please maintain the standard comment structure at the top of a new request handler, as [documented here](../README.md#request-handler-documentation)

This will allow for programmatic parsing of the request handlers to automatically generate catalog and documentation at a future date.
