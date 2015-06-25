desc "docker shell for fixture"
task :shell, [:fixture] do |t, args|
  require_relative "spec/support/buildpack_builder"
  require_relative "spec/support/path_helper"

  include PathHelper
  BuildpackBuilder.new(@debug)
  fixture_path = File.expand_path(fixtures_path(args[:fixture]))
  system("docker run -i -v #{fixture_path}:/src -t #{BuildpackBuilder::TAG} \"bash\"")
end
