require "tmpdir"
require_relative "proxy_builder"
require_relative "container_runner"

class ProxyRunner < ContainerRunner
  def initialize(config_ru = nil, delete = true)
    @tmpdir = write_config_ru(config_ru)

    options = {
      "Image" => ProxyBuilder::TAG
    }
    options["HostConfig"] = { "Binds" => ["#{@tmpdir}:/app/config/"] } if @tmpdir

    super(options, delete)
  end

  def destroy
    super
  ensure
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  private
  def write_config_ru(config_ru)
    tmpdir = nil

    if config_ru && config_ru.is_a?(String)
      tmpdir = Dir.mktmpdir
      File.open("#{tmpdir}/config.ru", "w") do |file|
        file.puts %q{require "sinatra"}
        file.puts config_ru
        file.puts "run Sinatra::Application"
      end
    end

    tmpdir
  end
end
