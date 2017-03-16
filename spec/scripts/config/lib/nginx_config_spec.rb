require 'fileutils'
require 'tmpdir'
require_relative "../../../spec_helper"
require_relative "../../../../scripts/config/lib/nginx_config"

RSpec.describe NginxConfig do
  let(:tmpdir)      { Dir.mktmpdir }
  let(:static_json) { "#{tmpdir}/static.json" }
  let(:config)      { NginxConfig.new(static_json) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "proxies" do
    context "origin does not end with /" do
      before do
        File.open(static_json, "w") do |file|
          file.puts <<-STATIC_JSON
{
  "proxies": {
    "/api": {
      "origin": "http://foo.heroku.com"
    }
  }
}
STATIC_JSON
        end
      end

      it "origin ends with a /" do
        expect(eval("proxies['/api']['origin']", config.context)).to eq("http://foo.heroku.com/")
      end
    end

    context "origin ends with /" do
      before do
        File.open(static_json, "w") do |file|
          file.puts <<-STATIC_JSON
{
  "proxies": {
    "/api": {
      "origin": "http://foo.heroku.com/"
    }
  }
}
STATIC_JSON
        end
      end

      it "should not repeat the /" do
        expect(eval("proxies['/api']['origin']", config.context)).to eq("http://foo.heroku.com/")
      end
    end
  end
end
