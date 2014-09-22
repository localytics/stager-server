# @description minimal auth implementation for 
#   launch/kill routes and any event handlers which should_authenticate
#   which checks basic auth headers of request against list of username:password pairs
#   in config
#
# @type authentication_strategy
#
# @dependencies none
#
# @config
#   users:
#     - username1:password1
#     - username2:password2
#     - username3:password3

class BasicAuthentication < AuthenticationStrategy

  def password_for_user(user)
    @settings.users.find {|ucs| ucs.split(':').first == user}.split(':').last
  end

  def authenticates?
    auth = Rack::Auth::Basic::Request.new(@request.env)
    return false unless auth.provided? and auth.basic? and auth.credentials
    user, pass = auth.credentials
    pass == password_for_user(user) 
  end
end
