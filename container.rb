module Docker
  class Container
    
    def env_hash
      return {} unless json['Config']['Env']
      json['Config']['Env'].inject({}) { |acc, kv| p = kv.split('='); acc[p[0].to_sym] = p[1]; acc }
    end
  end
end
