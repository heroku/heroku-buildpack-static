require "uri"
require "net/http"
require "fileutils"
require "json"
require "tmpdir"
require "docker"
require "concurrent/atomic/count_down_latch"
require_relative "path_helper"
require_relative "buildpack_builder"

class AppRunner
  include PathHelper

  class CasperJSError < StandardError; end

  PREFIX_PADDING = 8

  def self.boot2docker_ip
    %x(boot2docker ip).match(/([0-9]{1,3}\.){3}[0-9]{1,3}/)[0]
  rescue Errno::ENOENT
  end

  HOST_PORT      = "3000"
  HOST_IP        = boot2docker_ip || "127.0.0.1"
  CONTAINER_PORT = "3000"

  def initialize(fixture, env = {}, debug = false, circleci = false)
    @run       = false
    @debug     = debug
    @circleci  = circleci
    env.merge!("STATIC_DEBUG" => true) if @debug

    @container = Docker::Container.create(
      "Image"      => BuildpackBuilder::TAG,
      "Cmd"        => ["bash", "-c", "cp -rf /src/* /app/ && /app/bin/boot"],
      # Env format is [KEY1=VAL1 KEY2=VAL2]
      "Env"        => env.to_a.map {|i| i.join("=") },
      "HostConfig" => {
        "Binds" => ["#{fixtures_path(fixture)}:/src"],
        "PortBindings" => {
          "#{CONTAINER_PORT}/tcp" => [{
            "HostIp"   => HOST_IP,
            "HostPort" => HOST_PORT,
          }]
        }
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
        io_message = "#{"app".ljust(PREFIX_PADDING)} | #{stream}: #{chunk}"
        puts io_message if @debug
        io_stream << io_message if capture_io
        latch.count_down if chunk.include?("Starting nginx...")
      end
    }

    retn = run_thread.value

    if capture_io
      [retn, io_stream]
    else
      retn
    end
  ensure
    @container.stop
    container_thread.join
    io_stream.close_write
    @run = false
  end

  def test_js(name:, num:, path:, content:)
    uri      = to_uri(path)
    uri.host = @container.json["NetworkSettings"]["IPAddress"]

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("test.js", <<CONTENT)
casper.test.begin('#{name}', #{num}, function suite(test) {
  casper.start("#{uri.to_s}", function() {
#{content}
  });

  casper.run(function() {
    test.done();
  });
});
CONTENT
      end

      begin
        test_container = Docker::Container.create(
          'Image'      => BuildpackBuilder::TAG,
          'Tty'        => true,
          'EntryPoint' => "/bin/bash",
          'OpenStdin'  => true,
          'HostConfig' => {
            'Binds' => ["#{dir}:/test"]
          },
        )
        cmd            = ['bash', '-c', 'casperjs test /test/test.js']

        # CircleCI doesn't support docker-exec
        if @circleci
          cid = test_container.start.id
          cmd[2] = "'#{cmd[2]}'" # need to manually escape this for lxc-attach, but breaks in docker-exec
          IO.popen(%Q{sudo lxc-attach -n "$(docker inspect --format '{{.Id}}' #{cid})" -- #{cmd.join(' ')}}) do |io|
            print io.read
          end
          status = $?
        else
          _, _, status = test_container.tap(&:start).exec(cmd) do |stream, chunk|
            puts "#{"casperjs".ljust(PREFIX_PADDING)} | #{stream}: #{chunk}" if @debug
          end
        end
        raise CasperJSError.new("CasperJS Test Failed with exit status: #{status}") unless status == 0
      ensure
        test_container.stop
      end

    end
  end

  def get(path, capture_io = false, max_retries = 30)
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
      uri = URI(path)
      uri.host   = HOST_IP   if uri.host.nil?
      uri.port   = HOST_PORT if (uri.host == HOST_IP && uri.port != HOST_PORT) || uri.port.nil?
      uri.scheme = "http"    if uri.scheme.nil?

      Net::HTTP.get_response(URI(uri.to_s))
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

  def to_uri(path)
    uri = URI(path)
    uri.host   = HOST_IP   if uri.host.nil?
    uri.port   = HOST_PORT if (uri.host == HOST_IP && uri.port != HOST_PORT) || uri.port.nil?
    uri.scheme = "http"    if uri.scheme.nil?

    uri
  end
end
