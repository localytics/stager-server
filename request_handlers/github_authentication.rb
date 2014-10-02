# @description Uses github to authenticate
#   launch/kill routes and any event handlers that should_authenticate
#   on a per image basis
#   Requires that images are named after github repos
#   Requires a github oauth token in the request, and uses to determine
#   whether access is available for the repo whose name matches the image_name 
#   param, and whose owner is the configured repo_owner (see config below)
#   Provided oauth token must have repo scope
#
# @type authentication_strategy
#
# @dependencies none
#
# @config added to each image defined under images
#   images:
#     image_1:
#       repo_owner: 'github_user_account_which_owns_corresponding repo'

class GithubAuthentication < AuthenticationStrategy
  include GithubRequestHandler

  def authenticates?
    return false unless @request.params[:github_token] && !@request.params[:github_token].empty?
    begin
      gh = Github.new oauth_token: @request.params.delete('github_token')
      image_config = @settings.images[@request.params[:image_name]]
      gh.repos.get(image_config['repo_owner'], @request.params[:image_name])
    rescue
      false
    end
  end
end
