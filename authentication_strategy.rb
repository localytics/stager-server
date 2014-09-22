class AuthenticationStrategy < RequestHandler

  def authenticates?
    raise NotImplementedError
  end
end
