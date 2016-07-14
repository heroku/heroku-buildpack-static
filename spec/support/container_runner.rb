require "fiber"
require "docker"

class ContainerRunner
  extend Forwardable

  attr_reader :ip_address
  def_delegators :@container, :id

  def initialize(options, delete = true)
    @container  = Docker::Container.create(options)
    @ip_address = nil
    @thread     = nil
    @delete     = delete
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
    @container.delete(force: true) if @delete
  end
end
