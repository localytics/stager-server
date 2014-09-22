# @description Lauches new container when a 
#   pull request is opened in github
#   Uses source branch repo name as image_name,
#   and source branch name as container_name
#   Note you must provide both basic auth and a secret
#   when defining your hook in Github. See
#   http://stackoverflow.com/questions/18326549/github-service-hook-and-basic-authentication
#   http://developer.github.com/v3/repos/hooks/#create-a-hook
#
# @type event_listeners
#
# @depenencies LaunchOnGithubPullRequestOpened
#
# @config
#   github:
#    incoming_auth:
#      user: 'basic_auth_user_for_git_hook'
#      password: 'basic_auth_password_for_git_hook'
#      hook_secret: 'hook_secret'

class KillOnGithubPullRequestClosed < RequestHandler
  include GithubRequestHandler

  def will_handle?
    return false unless is_authorized?
    body = parse_body { |b| JSON.parse(b) }
    begin
      body['action'] == 'closed'
    rescue
      false
    end
  end

  def handle
    body = parse_body { |b| JSON.parse(b) }
    { action: 'kill', 
      image_name: body['pull_request']['head']['repo']['name'], 
      container_name: body['pull_request']['head']['ref'] }
  end
end

