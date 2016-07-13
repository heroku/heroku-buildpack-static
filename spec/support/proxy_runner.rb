require_relative "proxy_builder"
require_relative "container_runner"

class ProxyRunner < ContainerRunner
  def initialize(config_ru = nil, delete = true)
    options = {
      "Image" => ProxyBuilder::TAG
    }
    options["HostConfig"] = { "Binds" => ["#{config_ru}:/app/config/"] } if config_ru

    super(options, delete)
  end
end
