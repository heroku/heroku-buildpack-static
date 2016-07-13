require_relative "router_builder"
require_relative "container_runner"

class RouterRunner < ContainerRunner
  def self.boot2docker_ip
    %x(boot2docker ip).match(/([0-9]{1,3}\.){3}[0-9]{1,3}/)[0]
  rescue Errno::ENOENT
  end

  HTTP_PORT  = "80"
  HTTPS_PORT = "443"
  HOST_IP    = boot2docker_ip || "127.0.0.1"

  def initialize
    super({
      "name"       => "router",
      "Image"      => RouterBuilder::TAG,
      "HostConfig" => {
        "Links" => ["app:app"],
        "PortBindings" => {
          "#{HTTP_PORT}/tcp" => [{
            "HostIp"   => HOST_IP,
            "HostPort" => HTTP_PORT
          }],
          "#{HTTPS_PORT}/tcp" => [{
            "HostIp"   => HOST_IP,
            "HostPort" => HTTPS_PORT
          }]
        }
      }
    })
  end
end
