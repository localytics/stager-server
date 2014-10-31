![alt tag](http://i.imgur.com/CgQ18gd.png)

Stager automates the process of staging web applications by coordinating the creation and destruction of nginx vhosts with the creation and destruction of docker containers.

![alt tag](http://imgur.com/ZzUSaRV.gif)

##Installing

###Prerequisites

```bash
#install docker
curl -s https://get.docker.io/ubuntu/ | sudo sh #on ubuntu 12.04, see https://www.docker.io/gettingstarted/#h_installation for other platforms

#install build-essential
sudo apt-get install build-essential

#install ruby
sudo apt-get install ruby1.9.1-dev # tested version

#install bundler
sudo gem install bundler

#install nginx
sudo apt-get install nginx
```

###Quick Setup

```bash
# Add the user that will run Stager to the docker group, (you may need to log out and log back in after doing this)
sudo usermod -a -G docker user_to_add

# Give the docker group rw permissions to the nginx virtual hosts folder
sudo chown -R root:docker /etc/nginx/sites-enabled && sudo chmod -R 775 /etc/nginx/sites-enabled

# Expose Stager using default nginx vhost
HOST_NAME=stager_host.com sudo erb /path/to/stager/default_vhost.erb > /etc/nginx/sites-available/default

# Allow docker group to restart nginx without sudo password
# http://stackoverflow.com/questions/3011067/restart-nginx-without-sudo
echo %docker ALL=NOPASSWD: /path/to/stager/request_handlers/reload_nginx >> /etc/sudoers

# Start stager
cd /path/to/stager
bundle install
thin start
```

##Basic Use

Stager exposes three http endpoints, all of which expect POST requests.

####/launch

```bash
curl -d 'image_name=image_to_use&container_name=name_to_give_container' http://stager-instance.com/launch

#returns
http://name-to-give-container.stager-instance.com
```

Stager reads the image_to_use section of your config.yml images config to determine parameters to use when launching the container. See [Describing Images](#describing-images) below

All post params are defined as environment variables in the launched container, and any number of additional arbitrary parameters may be passed.

####/kill

```bash
curl -d 'image_name=image_to_use&container_name=name_to_give_container' http://stager-instance.com/kill

#returns
ok
```

####/event_receiver

This endpoint provides an extendable RPC interface for any configured event_listeners to utilize (see [Customization - event_listeners](#event_listeners) section below)

Return values can be provided by any event listener that matches a request to this endpoint.

##Configuration

###Environment Vars

The following environment variables can be defined to customize the behavior of your Stager instance:

```bash
MIN_PORT = 3200
MAX_PORT = 3500
```

Stager uses a FIFO approach to keep ports mapped from host machine to container within the min/max defined in the environment, so you can cap simultaneous containers this way, eg: MAX_PORT=3204 would cap at 5 simultaneous containers.

###Describing Images

```yaml
# config.yml
images:
  name_of_image: #this must correspond with an actual docker image on the server
   port: 80 
   # (required) The port on which your staged application will listen. This port will be mapped from any containers
   # launched from this image to an allocated port on the host machine
   command: 'bash /container_bootstrap_script.sh'
   # (required) The command which all containers created from this image will run when launched. 
   # This should perform any bootstrap steps required by your staged application.
   container_create_params:
   # (optional) additional docker params available on container creation. 
   # See http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#create-a-container
     Volumes: '/shared/config': {}
   container_start_params:
   # (optional) additional docker params available on container start. 
   # See http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#start-a-container
     Binds: ['/shared/config:/shared/config:ro']
```

Requests to /launch or /kill will expect the image_name parameter to have a corresponding config block under images in your config.yml

###Routing Strategies

Stager uses a RoutingStrategy to decide how the containers it manages are
exposed to the world. There are default strategies for nginx and haproxy.

####Nginx

```yaml
routing_strategy: 'NginxRoutingStrategy'
nginx:
  # Required if different from default
  target_dir: '/path/to/vhost'
  template_path: '/path/to/nginx.conf.erb'
```

####HAProxy

To use HAProxy instead of nginx, you can optionally specify the input 
haproxy template to use as well as where to output the config to.

```yaml
routing_strategy: 'HaproxyRoutingStrategy'
haproxy:
  # Defaults to /etc/haproxy/haproxy.cfg
  target_path: '/path/to/haproxy.cfg'
  # Internal default
  template_path: '/path/to/haproxy.cfg.erb'
```

###Authentication

Stager requires use of an authentication strategy when posting to the /launch or /kill endpoints. Currently two authentication strategies are available, Basic Auth and Github Auth. Both require additional parameters be sent with each request, which can be handled for you by using the [Stager cli gem](https://github.com/localytics/stager-client)

####Basic Authentication

Configuration
```yaml
# config.yml
authentication_strategy: 'BasicAuthentication'
users:
  - user_name:password
  - another_user_name:another_password
```

Authenticating
```bash
# curl
curl --user user_name:password -d 'image_name=name_of_image&container_name=name_for_container'

# Stager cli
stager configure auth_strategy=Basic username=user_name #run only once
stager launch name_of_image name_for_container #will prompt for pw
```

####Github Authentication

Configuration
```yaml
# config.yml
images:
  name_of_image: # should match repo which user must have access to in order to launch/kill
    repo_owner: user_or_org_which_owns_repo
authentication_strategy: 'GithubAuthentication'
# if you are using the Stager cli
event_listeners: 'GithubAuthorization'
github:
  client_id: 'client_id_for_your_github_app'
  client_secret: 'client_secret_for_your_github_app'
```

Authenticating
```bash
# curl
curl -d 'image_name=name_of_image&container_name=name_for_container&github_token=github_oauth_token_with_repo_scope'

# Stager cli
stager configure auth_strategy=Github #run only once
stager launch name_of_image name_for_container #will prompt for github creds once, then save oauth token for all future requests
```


If neither authentication strategy suits your use-case, new ones can easily be added. See [adding authentication strategies](request_handlers/README.md#authentication_strategy) for Stager, and [Stager cli](https://github.com/localytics/stager-client/blob/master/README.md#adding-auth-strategies)

##Customization 

At this point you'll have a fully operational Stager, but you can easily customize the behavior of your instance and integrate with other systems using simple plugins referred to as request handlers.

###Request Handler Documentation

Every request handler contains a standardized comment documenting its purpose and usage. The comment contains the following elements:

*  @description - Describes the purpose of the request handler
*  @type - One or more of the types listed below where the request handler is appropriate to use, authentication_strategy, post_launch_handlers, pre_kill_handlers, or event_listeners
*  @dependencies - Any other request handlers that this request handler requires to function properly
*  @config - Required updates to config.yml that this request handler requires to function properly

There are five types of request handlers supported by Stager, each of which are invoked at different times in the lifecycle of a request.

###authentication_strategy

This request handler is invoked before processing a launch or kill request, as well as any event_listeners which explicitly specify that they should authenticate.

```yaml
# config.yml
authentication_strategy: 'BasicAuthentication'
```

Included authentication strategies:

*  [BasicAuthentication](request_handlers/basic_authentication.rb)
*  [GithubAuthentication](request_handlers/github_authentication.rb)

###container_rotation_strategy

This request handler is optional, and when configured is consulted when Stager needs to make room to process a launch request based on the configured
port range (all ports are allocated,) and simply decides which container will be killed to make room for the new one being launched.

```yaml
# config.yml
container_rotation_strategy: 'EvergreenExceptionsContainerRotationStrategy'
```

Included container rotation strategies:

* [EvergreenExceptionsContainerRotationStrategy](request_handlers/evergreen_exceptions_container_rotation_strategy.rb)

When no container\_rotation\_strategy is defined, basic FIFO is used.

###post_launch_handlers

These request handlers are invoked immediately after a container is launched

```yaml
# config.yml
post_launch_handlers:
  - 'AddGithubPullReqeustCommentOnLaunch'
  - 'PostToSlackOnLaunch'
```

Included post launch handlers:

*  [AddGithubPullRequestCommentOnLaunch](request_handlers/add_github_pull_request_comment_on_launch.rb)
*  [PostToSlackOnLaunch](request_handlers/post_to_slack_on_launch.rb)

###pre_kill_handlers

These request handlers are invoked immediately before a container is killed

```yaml
# config.yml
pre_kill_handlers:
  - 'RemoveGithubPullRequestCommentsOnKill'
```

Included pre kill handlers:

* [RemoveGithubPullRequestCommentsOnKill](request_handlers/remove_github_pull_request_comments_on_kill.rb)

###event_listeners

These request handlers are invoked when requests are made to the /event_receiver endpoint. The first event listener to volunteer for handling a request to /event_receiver will handle the request, and only one will fire per request.

```yaml
# config.yml
event_listeners:
  - 'LaunchOnGithubPullRequestOpened'
  - 'KillOnGithubPullRequestClosed'
```

Included event listeners:

*  [GithubAuthorization](request_handlers/github_authorization.rb)
*  [LaunchOnGithubPullRequestOpened](request_handlers/launch_on_github_pull_request_opened.rb)
*  [KillOnGithubPullRequestClosed](request_handlers/kill_on_github_pull_request_closed.rb)
*  [RequestInspector](request_handlers/request_inspector.rb)

###Creating Request Handlers

Request handlers are simple class definitions with a maximum of two methods required, making them very easy to create. Depending on the type of request handler you are creating, different instance variables are made available to those methods for interacting with the current state of the app.

For details on the required methods and exposed instance variables for the various types of request handlers, see the [request handlers readme](request_handlers/README.md)

##Contributing

*  Fork the repo
*  Create a branch
*  Make your changes 
  * Include standardized comment if adding request handlers
  * Spaces not tabs, 2 space indents
*  Update docs to reflect changes
*  Open a pull request
