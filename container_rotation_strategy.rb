class ContainerRotationStrategy < RequestHandler

  def container_to_rotate
    raise NotImplementedError
  end
end

