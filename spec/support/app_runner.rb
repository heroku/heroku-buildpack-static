require "uri"
require "net/http"
require "fileutils"
require "json"
require "docker"
require "concurrent/atomic/count_down_latch"
require_relative "path_helper"
require_relative "buildpack_builder"

class AppRunner
  include PathHelper

  def self.boot2docker_ip
    %x(boot2docker ip).match(/([0-9]{1,3}\.){3}[0-9]{1,3}/)[0]
  rescue Errno::ENOENT
  end

  HOST_PORT      = "3000"
  HOST_IP        = boot2docker_ip || "127.0.0.1"
  CONTAINER_PORT = "3000"

  def initialize(fixture, debug = false)
    @debug     = debug
    @container = Docker::Container.create(
      'Image'      => BuildpackBuilder::TAG,
      'Cmd'        => ["bash", "-c", "cp -rf /src/* /app/ && /app/bin/boot"],
      'HostConfig' => {
        'Binds' => ["#{fixtures_path(fixture)}:/src"],
        'PortBindings' => {
          "#{CONTAINER_PORT}/tcp" => [{
            "HostIp" => HOST_IP,
            "HostPort": HOST_PORT,
          }]
        }
      }
    )
  end

  def run
    latch = Concurrent::CountDownLatch.new(1)
    run_thread = Thread.new {
      latch.wait(0.5)
      yield(@container)
    }
    container_thread = Thread.new {
      @container.tap(&:start).attach do |stream, chunk|
        puts "#{stream}: #{chunk}" if @debug
        latch.count_down if chunk.include?("Starting nginx...")
      end
    }

    run_thread.join
    @container.stop
    container_thread.join
  end

  def get(path, max_retries = 5)
    response = nil

    run do
      network_retry(max_retries) do
        uri = URI("#{path}")
        uri.host   = HOST_IP   if uri.host.nil?
        uri.port   = HOST_PORT if (uri.host == HOST_IP && uri.port != HOST_PORT) || uri.port.nil?
        uri.scheme = "http"    if uri.scheme.nil?

        response = Net::HTTP.get_response(URI(uri.to_s))
      end
    end

    response
  end

  def destroy
    @container.delete(force: true) unless @debug
  end

  private
  def network_retry(max_retries, retry_count = 0)
    yield
  rescue Errno::ECONNRESET, EOFError
    if retry_count < max_retries
      puts "Retry Count: #{retry_count}" if @debug
      sleep(0.01 * retry_count)
      retry_count += 1
      retry
    end
  end
end
