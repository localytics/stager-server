# @description Responds with json data listing running containers for specified image
#
# @type event_listeners
#
# @dependencies none
#
# @config none

class StatusReport < RequestHandler

  def should_authenticate?
    true
  end

  def will_handle?
    @request.params[:action] == 'status' && @request.params[:image_name]
  end

  def handle
    @response.headers['Content-Type'] = 'application/json'
    r = ::Docker::Container.all.find_all {|c| c.env_hash[:image_name] == @request.params[:image_name]}.
      map do |c| 
        { image_name: c.env_hash[:image_name], container_name: c.env_hash[:container_name],
          url: "#{@request.scheme}://#{c.env_hash[:container_name].slugify}.#{@request.env['HTTP_HOST']}",
          started_at: c.json['Created'] }
      end
    r.to_json
  end
end


