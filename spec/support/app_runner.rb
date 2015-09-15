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

  def initialize(fixture, env = {}, debug = false)
    @run       = false
    @debug     = debug
    env.merge!("STATIC_DEBUG" => true) if @debug
    @container = Docker::Container.create(
      'Image'      => BuildpackBuilder::TAG,
      'Cmd'        => ["bash", "-c", "cp -rf /src/* /app/ && /app/bin/boot"],
      # Env format is [KEY1=VAL1 KEY2=VAL2]
      'Env'        => env.to_a.map {|i| i.join("=") },
      'HostConfig' => {
        'Binds' => ["#{fixtures_path(fixture)}:/src"],
        'PortBindings' => {
          "#{CONTAINER_PORT}/tcp" => [{
            "HostIp"   => HOST_IP,
            "HostPort" => HOST_PORT,
          }]
        },
        'Privileged': true
      }
    )
  end

  def run(capture_io = false)
    @run       = true
    retn       = nil
    latch      = Concurrent::CountDownLatch.new(1)
    io_stream  = StringIO.new
    run_thread = Thread.new {
      latch.wait(0.5)
      yield(@container)
    }
    container_thread = Thread.new {
      @container.tap(&:start).attach do |stream, chunk|
        io_message = "#{stream}: #{chunk}"
        puts io_message if @debug
        io_stream << io_message if capture_io
        latch.count_down if chunk.include?("Starting nginx...")
      end
    }

    retn = run_thread.value
    @container.stop
    container_thread.join
    io_stream.close_write
    @run = false

    if capture_io
      [retn, io_stream]
    else
      retn
    end
  end

  def get(path, capture_io = false, max_retries = 20)
    if @run
      get_retry(path, max_retries)
    else
      run(capture_io) { get_retry(path, max_retries) }
    end
  end

  def destroy
    @container.delete(force: true) unless @debug
  end

  private
  def get_retry(path, max_retries)
    network_retry(max_retries) do
      uri = URI("#{path}")
      uri.host   = HOST_IP   if uri.host.nil?
      uri.port   = HOST_PORT if (uri.host == HOST_IP && uri.port != HOST_PORT) || uri.port.nil?
      uri.scheme = "http"    if uri.scheme.nil?

      Net::HTTP.get_response(URI(uri.to_s))
    end
  end

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
