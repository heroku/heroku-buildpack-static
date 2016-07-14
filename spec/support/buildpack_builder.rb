require_relative "path_helper"
require_relative "docker_builder"

class BuildpackBuilder
  include PathHelper
  include DockerBuilder

  TAG = "hone/static:cedar-14"

  def initialize(debug = false, intermediates = false)
    @debug         = debug
    @intermediates = intermediates
    @image         = build(
      context: buildpack_path.to_s,
      dockerfile: docker_path("app/Dockerfile").relative_path_from(buildpack_path),
      tag: TAG,
      intermediates: @intermediates,
      debug: @debug
    )
  end
end
