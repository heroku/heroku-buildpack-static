require "fiber"
require "docker"

class ContainerRunner
  attr_reader :ip_address

  def initialize(options)
    @container  = Docker::Container.create(options)
    @ip_address = nil
    @thread     = nil
  end

  def start
    @thread = Fiber.new {
      @container.start
      Fiber.yield @container.json["NetworkSettings"]["IPAddress"]
    }
    @ip_address = @thread.resume
  end

  def stop
    @container.stop
    @thread.resume if @thread.alive?
  end

  def destroy
    @container.delete(force: true)
  end
end
