require_relative "spec_helper"
load File.join(File.dirname(__FILE__), '../scripts/config/make-config')

RSpec.describe "NginxConfig#to_regex" do
  samples = [
    ['/foo/',    '/foo/'],
    ['/foo/*',   '/foo/[^/]*'],
    ['/foo/**',  '/foo/.*'],
    ['/cache/*', '/cache/[^/]*'],
  ]

  samples.each do |(input, output)|
    it "converts #{input} to #{output}" do
      result = NginxConfig.to_regex(input)
      expect(result).to eq output
    end
  end
end
