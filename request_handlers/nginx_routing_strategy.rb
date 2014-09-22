# @description 
#
# Adds or removes nginx vhosts when
# containers are added or removed
#
# @dependencies none
#
# @config
#   nginx:
#     - target_dir: /etc/nginx/sites-enabled
#     - template_path: /etc/nginx/sites-enabled

class NginxRoutingStrategy < RoutingStrategy


  def handle
    clean
    write unless kill_event_type?
    reload
  end

  private

  def reload
    %x( sudo ./request_handlers/reload_nginx )
  end

  def template_path
    @settings.haproxy['template_path'] || './request_handlers/nginx.conf.erb'
  end

  def port
    @ports.next_port
  end

  def host
    @request.host
  end

  def slug
    name.slugify
  end

  def target_path
    File.join(target_dir, slug)
  end

  def name
    @request.params[:container_name]
  end

  def target_dir
    @settings.nginx['target_dir'] || '/etc/nginx/sites-enabled'
  end

end
