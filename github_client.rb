require 'base64'
require 'faraday'
require 'json'
require 'oauth2'

class Github
  API = 'https://api.github.com'

  def initialize(basic_auth: nil, oauth_token: nil, client_id: nil, client_secret: nil)
    @basic_auth = basic_auth
    @oauth_token = oauth_token
    @client_id = client_id
    @client_secret = client_secret
  end

  def authorize_url(scope:, state:, redirect_uri:)
    oauth_client.auth_code.authorize_url(scope: scope, state: state, redirect_uri: redirect_uri)
  end

  def get_token(code)
    oauth_client.auth_code.get_token(code)
  end

  def repos
    Repos.new(self)
  end

  def issues
    Issues.new(self)
  end

  def request(method, path, body = nil)
    response = connection.public_send(method, path) do |req|
      req.headers['Accept'] = 'application/vnd.github+json'
      req.headers['Content-Type'] = 'application/json'
      if @oauth_token
        req.headers['Authorization'] = "Bearer #{@oauth_token}"
      elsif @basic_auth
        req.headers['Authorization'] = "Basic #{Base64.strict_encode64(@basic_auth)}"
      end
      req.body = JSON.generate(body) if body
    end
    raise "GitHub API #{response.status}" unless response.success?
    return nil if response.body.nil? || response.body.empty?
    JSON.parse(response.body)
  end

  class Repos
    def initialize(client)
      @client = client
    end

    def get(owner, repo)
      @client.request(:get, "/repos/#{owner}/#{repo}")
    end
  end

  class Issues
    def initialize(client)
      @client = client
    end

    def comments
      Comments.new(@client)
    end
  end

  class Comments
    def initialize(client)
      @client = client
    end

    def create(owner, repo, number, body:)
      @client.request(:post, "/repos/#{owner}/#{repo}/issues/#{number}/comments", { body: body })
    end

    def all(owner, repo, number)
      @client.request(:get, "/repos/#{owner}/#{repo}/issues/#{number}/comments")
    end

    def delete(owner, repo, id)
      @client.request(:delete, "/repos/#{owner}/#{repo}/issues/comments/#{id}")
    end
  end

  private

  def connection
    @connection ||= Faraday.new(url: API)
  end

  def oauth_client
    @oauth_client ||= OAuth2::Client.new(
      @client_id,
      @client_secret,
      site: 'https://github.com',
      authorize_url: '/login/oauth/authorize',
      token_url: '/login/oauth/access_token'
    )
  end
end
