require_relative "docker_builder"
require_relative "path_helper"

class ProxyBuilder
  include DockerBuilder
  include PathHelper

  TAG = "hone/static-proxy:latest"

  def initialize(debug = false, intermediates = false)
    @build = build(
      context: docker_path("proxy").to_s,
      debug: debug,
      tag: TAG,
      intermediates: intermediates
    )
  end
end
