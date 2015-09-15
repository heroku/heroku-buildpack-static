desc "docker shell for fixture"
task :shell, [:fixture] do |t, args|
  require_relative "spec/support/buildpack_builder"
  require_relative "spec/support/path_helper"

  include PathHelper
  BuildpackBuilder.new(@debug)
  fixture_path    = File.expand_path(fixtures_path(args[:fixture]))
  cmd = %Q{docker run -i -v #{fixture_path}:/src -t #{BuildpackBuilder::TAG} /bin/bash -c "/app/bin/config/make-config && bash"}
  puts cmd
  system cmd
end

task :server, [:fixture] do |t, args|
  require_relative "spec/support/buildpack_builder"
  require_relative "spec/support/app_runner"

  debug       = true
  thread_name = :app_thread

  Signal.trap("INT") do
    Thread.list.detect {|thread| thread[:name] == thread_name }.wakeup
  end

  BuildpackBuilder.new(debug)
  app = AppRunner.new(args[:fixture], {}, debug)
  app.run do
    Thread.current[:name] = thread_name
    Thread.stop
  end
end
