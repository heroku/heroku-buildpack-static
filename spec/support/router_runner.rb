require_relative "router_builder"
require_relative "container_runner"

class RouterRunner < ContainerRunner
  def self.boot2docker_ip
    %x(boot2docker ip).match(/([0-9]{1,3}\.){3}[0-9]{1,3}/)[0]
  rescue Errno::ENOENT
  end

  CONTAINER_PORT = "80"
  HOST_PORT      = "80"
  HOST_IP        = boot2docker_ip || "127.0.0.1"

  def initialize
    super({
      "name"       => "router",
      "Image"      => RouterBuilder::TAG,
      "HostConfig" => {
        "Links" => ["app:app"],
        "PortBindings" => {
          "#{CONTAINER_PORT}/tcp" => [{
            "HostIp"   => HOST_IP,
            "HostPort" => HOST_PORT,
          }]
        }
      }
    })
  end
end
