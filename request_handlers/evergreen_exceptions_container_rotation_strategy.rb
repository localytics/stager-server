# @description FIFO container rotation, except for 
#   containers whose names are found in a list defined in config
#
# @type container_rotation_strategy
#
# @dependencies none
#
# @config
#   evergreen_containers:
#     - evergreen_container_name_1
#     - evergreen_container_name_2

class EvergreenExceptionsContainerRotationStrategy < ContainerRotationStrategy

  def container_to_rotate
    ::Docker::Container.all.compact.
      reject { |c| @settings.evergreen_containers.include? c.env_hash[:container_name] }.
      find_all {|c| c.env_hash[:container_name] && !c.env_hash[:container_name].empty?}.
      sort_by {|c| c.json['Created']}.first
  end
end
