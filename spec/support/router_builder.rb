require_relative "path_helper"
require_relative "docker_builder"

class RouterBuilder
  include PathHelper
  include DockerBuilder

  TAG = "hone/static-router:latest"

  def initialize(debug = false, intermediates = false)
    @image = build(
      context: docker_path("/router").to_s,
      tag: TAG,
      intermediates: intermediates,
      debug: debug
    )
  end
end
