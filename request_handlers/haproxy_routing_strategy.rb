# @description 
#
# Updates HAProxy to expose the ports for the current
# docker containers
#
# @dependencies none
#
# @config
#   haproxy:
#     target_path: /etc/haproxy/haproxy.cfg
#     template_path: /etc/haproxy/haproxy.cfg.erb
#     bind: '*:8080'

class HaproxyRoutingStrategy < RoutingStrategy

  def handle
    write
    reload
  end

  private

  def containers
    selected_containers.map do |c|
      json = c.json
      hosts = json['NetworkSettings']['Ports'].map { |port| port[1] }.flatten
      {
        name: json['Name'].slice(1..-1).slugify,
        address: "#{hosts.first['HostIp']}:#{hosts.first['HostPort']}",
        json: json
      }
    end
  end

  def selected_containers
    if kill_event_type? && container
      ::Docker::Container.all.select{ |c| c.id != container.id }
    else
      ::Docker::Container.all
    end
  end

  def reload
    %x( sudo ./request_handlers/reload_haproxy )
  end

  def target_path
    @settings.haproxy['target_path'] || '/etc/haproxy/haproxy.cfg'
  end

  def template_path
    @settings.haproxy['template_path'] || './request_handlers/haproxy.cfg.erb'
  end

  def bind
    @settings.haproxy['bind'] || '*:8080'
  end

end
