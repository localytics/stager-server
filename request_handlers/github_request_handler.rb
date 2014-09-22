module GithubRequestHandler

  def secret_is_valid?
    signature = @request.env["HTTP_X_HUB_SIGNATURE"] || ""
    secret = signature[5..-1]
    return false unless secret && settings.github['incoming_auth']['hook_secret']
    digest = OpenSSL::Digest::Digest.new('sha1')
    body = @request.body.read
    @request.body.rewind
    secret == OpenSSL::HMAC.hexdigest(digest, @settings.github['incoming_auth']['hook_secret'], body)
  end

  def is_authorized?
    return false unless settings.github && settings.github['incoming_auth'] 
    auth = Rack::Auth::Basic::Request.new(@request.env)
    secret_is_valid? && auth.provided? && auth.basic? && auth.credentials && 
      auth.credentials == [settings.github['incoming_auth']['user'], settings.github['incoming_auth']['password']]
  end

  def github_api
    auth = settings.github['outgoing_auth']
    @gh ||= ::Github.new basic_auth: "#{auth['user']}:#{auth['password']}"
  end
end
