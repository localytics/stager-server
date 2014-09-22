# @description drops you at a pry session
#   with the request body stored in the body variable.
#   Useful for inspecting incoming payloads when building
#   new event_listeners
#
# @type event_listeners
#
# @dependencies none
#
# @config none

class RequestInspector < RequestHandler

  def will_handle?
    true
  end

  def handle
    body = parse_body {|body| JSON.parse(body)}
    binding.pry
  end
end
