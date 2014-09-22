# @description Looks for associated Github pull request
#   after container is killed and removes any comments
#   posted by the account configured for outgoing Github
#   authentication from that pull request if it exists
#
# @type pre_kill_handlers
#
# @dependencies LaunchOnGithubPullRequestOpened, augments AddGithubPullRequestCommentOnLaunch
#
# @config
#  github:
#    outgoing_auth:
#      user: 'username_for_outgoing_github_requests'
#      password: 'password_for_outgoing_github_requests'

class RemoveGithubPullRequestCommentsOnKill < RequestHandler
  include GithubRequestHandler

  def will_handle?
    ([:repo_owner, :pull_request_number] & @container.env_hash.keys).size == 2
  end

  def handle
    e = @container.env_hash
    comments = github_api.issues.comments.all e[:repo_owner], e[:image_name], e[:pull_request_number]
    stager_comments = comments.find_all {|c| c['user']['login'] == @settings.github['outgoing_auth']['user'] }
    stager_comments.each { |c| github_api.issues.comments.delete e[:repo_owner], e[:image_name], c.id }
  end
end

