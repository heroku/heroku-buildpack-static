require "tmpdir"
require "fileutils"
require "docker"
require_relative "path_helper"

class BuildpackBuilder
  include PathHelper

  TAG = "hone/static:cedar-14"

  def initialize(debug = false, intermediates = false)
    @debug         = debug
    @intermediates = intermediates
    @image         = build_image
  end

  def build_image
    print_output =
      if @debug
        -> (chunk) {
          json = JSON.parse(chunk)
          puts json["stream"]
        }
      else
        -> (chunk) { nil }
      end

    Docker::Image.build_from_dir(buildpack_path.to_s, 't' => TAG, 'rm' => !@intermediates, 'dockerfile' => "spec/support/docker/Dockerfile", &print_output)
  end
end
