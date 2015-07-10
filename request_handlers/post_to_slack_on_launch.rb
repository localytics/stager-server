# @description Posts a message to specified slack
#   chat room on container launch after the launch has completed,
#   with a link to the address where
#   the images configured expose port is available
#
# @type post_launch_handlers
#
# @dependencies none
#
# @config
#   slack:
#     webhook_url: 'webhook_url'
#     username: 'slack_username'
#     channel: 'slack_channel'
class PostToSlackOnLaunch < RequestHandler

  def will_handle?
    true
  end

  def handle
    Slack::Post.configure(
      webhook_url: @settings.slack['webhook_url'],
      username: @settings.slack['username'])
    Slack::Post.post "#{@request.params[:image_name]}/#{@request.params[:container_name]} is now staged at " <<
        "#{@request.scheme}://#{@request.params[:container_name].slugify}.#{@request.env['HTTP_HOST']}",
        @settings.slack['channel']
  end
end
