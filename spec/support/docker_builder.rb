require "docker"

module DockerBuilder
  def build(context:, tag:, intermediates:, debug:, dockerfile: nil)
    print_output =
      if debug
        -> (chunk) {
          json = JSON.parse(chunk)
          puts json["stream"]
        }
      else
        -> (chunk) { nil }
      end

    options = {
      't'  => tag,
      'rm' => !intermediates,
    }
    options["dockerfile"] = dockerfile

    Docker::Image.build_from_dir(context, options, &print_output)
  end
end
