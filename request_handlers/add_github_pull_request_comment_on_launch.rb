# @description Adds a comment to the pull request that triggered container
#   launch after the launch has completed, with a link to the address where
#   the images configured expose port is available
#
# @type post_launch_handlers 
#
# @dependencies LaunchOnGithubPullRequestOpened
#
# @config 
#  github:
#    outgoing_auth:
#      user: 'username_for_outgoing_github_requests'
#      password: 'password_for_outgoing_github_requests'

class AddGithubPullRequestCommentOnLaunch < RequestHandler
  include GithubRequestHandler

  def will_handle?
    ([:repo_owner, :pull_request_number] & @request.params.keys).size == 2 &&
      !@request.params.keys.include?(:sync)
  end

  def handle
    github_api.issues.comments.
      create @request.params[:repo_owner], @request.params[:image_name], @request.params[:pull_request_number], 
        body: "Branch is now staged at " <<
        "#{@request.scheme}://#{@request.params[:container_name].slugify}.#{@request.env['HTTP_HOST']}"
  end
end
