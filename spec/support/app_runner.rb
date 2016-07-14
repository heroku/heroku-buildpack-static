require "uri"
require "net/http"
require "fileutils"
require "json"
require "docker"
require "concurrent/atomic/count_down_latch"
require_relative "path_helper"
require_relative "buildpack_builder"
require_relative "router_runner"
require_relative "../../scripts/config/lib/nginx_config_util"

class AppRunner
  include PathHelper

  attr_reader :proxy

  def initialize(fixture, proxy = nil, env = {}, debug = false, delete = true)
    @run    = false
    @debug  = debug
    @proxy  = nil
    @delete = delete
    env.merge!("STATIC_DEBUG" => "true") if @debug

    app_options = {
      "Image"      => BuildpackBuilder::TAG,
      # Env format is [KEY1=VAL1 KEY2=VAL2]
      "Env"        => env.to_a.map {|i| i.join("=") },
      "HostConfig" => {
        "Binds" => ["#{fixtures_path(fixture)}:/src"]
      }
    }

    if proxy
      @proxy = ProxyRunner.new(proxy, @delete)
      app_options["Links"] = ["#{@proxy.id}:proxy"]
      @proxy.start

      # need to interpolate the PROXY_IP_ADDRESS since env is a parameter to this constructor and
      # the proxy app needs to be started first to get the ip address docker provides.
      # it's a bootstrapping problem to do env var substitution
      env.select {|_, value| value.include?("${PROXY_IP_ADDRESS}") }.each do |key, value|
        env[key] = NginxConfigUtil.interpolate(value, {"PROXY_IP_ADDRESS" => @proxy.ip_address})
        app_options["Env"] = env.to_a.map {|i| i.join("=") }
      end
    end

    @app    = Docker::Container.create(app_options)
    @router = RouterRunner.new(@app.id, @delete)
  end

  def run(capture_io = false)
    @run       = true
    retn       = nil
    latch      = Concurrent::CountDownLatch.new(1)
    io_stream  = StringIO.new
    run_thread = Thread.new {
      latch.wait(0.5)
      yield
    }
    container_thread = Thread.new {
      @app.tap(&:start).attach do |stream, chunk|
        io_message = "#{stream}: #{chunk}"
        puts io_message if @debug
        io_stream << io_message if capture_io
        latch.count_down if chunk.include?("Starting nginx...")
      end
    }
    @router.start

    retn = run_thread.value

    if capture_io
      [retn, io_stream]
    else
      retn
    end
  ensure
    @app.stop
    @router.stop
    container_thread.join
    io_stream.close_write
    @run = false
  end

  def get(path, capture_io = false, max_retries = 60)
    if @run
      get_retry(path, max_retries)
    else
      run(capture_io) { get_retry(path, max_retries) }
    end
  end

  def destroy
    if @proxy
      @proxy.stop
      @proxy.destroy
    end
    @router.destroy
    @app.delete(force: true) if @delete
  end

  private
  def get_retry(path, max_retries)
    network_retry(max_retries) do
      uri = URI(path)
      uri.host   = RouterRunner::HOST_IP if uri.host.nil?
      uri.scheme = "http" if uri.scheme.nil?

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      ) do |http|
        request = Net::HTTP::Get.new(uri.to_s)
        http.request(request)
      end
    end
  end

  def network_retry(max_retries, retry_count = 0)
    yield
  rescue Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED
    if retry_count < max_retries
      puts "Retry Count: #{retry_count}" if @debug
      sleep(0.01 * retry_count)
      retry_count += 1
      retry
    end
  end
end
