# @description provides rpc at event_receiver endpoint
#   to provide "state" for Github oauth web flow, then
#   create an authorization for the configured app with
#   repo scope required for GithubAuthentication, and
#   render the token for that authorization
#   Used by Github auth_strategy in the stager cli gem
#   You must register a github app for use in this process
#
# @type event_listeners
#
# @dependencies none but augments GithubAuthentication
#
# @config none
#   github:
#     client_id: 'client_id_for_your_github_app'
#     client_secret: 'client_secret_for_your_github_app'

class GithubAuthorization < RequestHandler

  ::Stager.set :github_states, {}
  ::Stager.set :github_tokens, {}

  def will_handle?
    ['get_oauth_url', 'create_github_token', 'get_github_token'].include? @request.params[:action]
  end

  def state_key
    "gh_oauth_state_#{@request.ip.gsub(/\./, '')}".to_sym
  end

  def get_oauth_url
    @settings.github_states[@request.ip] = Digest::MD5.hexdigest("#{@request.ip}#{Time.now.to_s}")
    github_api.authorize_url scope: 'repo', state: @settings.github_states[@request.ip],
      redirect_uri:"#{@request.scheme}://#{@request.env['HTTP_HOST']}/event_receiver?action=create_github_token"
  end

  def consume_state_and_return_ip
    return nil unless (saved_state = @settings.github_states.find { |k, v| v == @request.params[:state] })
    @settings.github_states.delete saved_state[0]
    saved_state[0]
  end
  
  def github_api
    ::Github.new client_id: @settings.github[:client_id], 
      client_secret: @settings.github[:client_secret]
  end

  def create_github_token
    return unless (@request.params[:code] && ip = consume_state_and_return_ip)
    @settings.github_tokens[ip] = github_api.get_token(@request.params[:code]).token
    'Your Github Authorization is ready, please resume your Stager cli request'
  end

  def get_github_token
    return unless @settings.github_tokens[@request.ip]
    @settings.github_tokens.delete @request.ip
  end

  def handle
    self.send(@request.params[:action])
  end
end
