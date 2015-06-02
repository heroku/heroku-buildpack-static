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

  HOST_PORT      = "3000"
  HOST_IP        = "127.0.0.1"
  CONTAINER_PORT = "3000"

  def initialize(fixture, debug = false)
    @debug     = debug
    @image     = build_image(fixture)
    @container = Docker::Container.create(
      'Image'      => @image.id,
      'HostConfig' => {
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
        uri      = URI("http://#{HOST_IP}:#{HOST_PORT}/#{path}")
        response = Net::HTTP.get_response(uri)
      end
    end

    response
  end

  def destroy
    unless @debug
      @container.delete(force: true)
      @image.remove(force: true)
    end
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

  def build_image(fixture)
    image = nil

    Dir.mktmpdir do |tmpdir|
      print_output =
        if @debug
          -> (chunk) {
            json = JSON.parse(chunk)
            puts json["stream"]
          }
        else
          -> (chunk) { nil }
        end

      FileUtils.cp_r(Dir.glob(fixtures_path(fixture) + "*"), tmpdir)
      dockerfile = "#{tmpdir}/Dockerfile"
      unless File.exist?(dockerfile)
        File.open(dockerfile, "w") do |file|
          file.puts "FROM #{BuildpackBuilder::TAG}"
        end
      end
      image = Docker::Image.build_from_dir(tmpdir, 'rm' => true, &print_output)
    end

    image
  end
end
