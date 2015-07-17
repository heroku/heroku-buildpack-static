require "fileutils"
require_relative "spec_helper"
require_relative "support/app_runner"
require_relative "support/buildpack_builder"
require_relative "support/path_helper"

RSpec.describe "Simple" do
  before(:all) do
    @debug = false
    BuildpackBuilder.new(@debug)
  end

  after do
    app.destroy
  end

  let(:app)  { AppRunner.new(name, env, @debug) }

  let(:name) { "hello_world" }
  let(:env)  { Hash.new }

  it "should serve out of public_html by default" do
    response = app.get("/")
    expect(response.code).to eq("200")
    expect(response.body.chomp).to eq("Hello World")
  end

  describe "no config" do
    let(:name) { "no_config" }

    it "should serve out of public_html by default" do
      response = app.get("/")
      expect(response.code).to eq("200")
      expect(response.body.chomp).to eq("Hello World")
    end
  end

  describe "root" do
    let(:name) { "different_root" }

    it "should serve assets out of user defined root" do
      response = app.get("/")
      expect(response.code).to eq("200")
      expect(response.body.chomp).to eq("Hello from dist/")
    end
  end

  describe "clean_urls" do
    let(:name) { "clean_urls" }

    it "should drop the .html extension from URLs" do
      response = app.get("/foo")
      expect(response.code).to eq("200")
      expect(response.body.chomp).to eq("foobar")
    end
  end

  describe "routes" do
    let(:name) { "routes" }

    it "should support custom routes" do
      app.run do
        response = app.get("/foo.html")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello world")

        response = app.get("/route/foo")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello from route")

        response = app.get("/route/foo/bar")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello from route")
      end
    end

    context "whitelist" do
      let(:name) { "routes_excepts" }

      it "redirects paths not on the except list" do
        response = app.get("/foo.html")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello world")
      end

      it "should not override the except list" do
        app.run do
          response = app.get("/assets/app.js")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("{}")

          response = app.get("/api/v1/items.json")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq('{ "item": "foo" }')
        end
      end
    end
  end

  describe "redirects" do
    let(:name) { "redirects" }

    it "should redirect and respect the http code & remove the port" do
      response = app.get("/old/gone")
      expect(response.code).to eq("302")
      expect(response["location"]).to eq("http://#{AppRunner::HOST_IP}/")
    end
  end

  describe "https only" do
    let(:name) { "https_only" }

    it "should redirect http to https" do
      response = app.get("/foo")
      expect(response.code).to eq("301")
      expect(response['location']).to eq("https://#{AppRunner::HOST_IP}/foo")
    end
  end

  describe "custom error pages" do
    let(:name) { "custom_error_pages" }

    it "should render the error page for a 404" do
      response = app.get("/ewat")
      expect(response.code).to eq("404")
      expect(response.body.chomp).to eq("not found")
    end
  end

  describe "proxies" do
    include PathHelper

    let(:name)              { "proxies" }
    let(:static_json_path)  { fixtures_path("proxies/static.json") }
    let(:setup_static_json) do
      Proc.new do |path|
        File.open(static_json_path, "w") do |file|
          file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}#{path}"
    }
  }
}
STATIC_JSON

        end
      end
    end

    after do
      FileUtils.rm(static_json_path)
    end

    context "trailing slash" do
      before do
        setup_static_json.call("/foo/")
      end

      it "should proxy requests" do
        response = app.get("/api/bar/")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("api")
      end
    end

    context "without a trailing slash" do
      before do
        setup_static_json.call("/foo")
      end

      it "should proxy requests" do
        response = app.get("/api/bar/")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("api")
      end
    end

    context "with custom routes" do
      before do
        File.open(static_json_path, "w") do |file|
          file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}/foo"
    },
    "/proxy/": {
      "origin": "http://#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}/foo"
    }
  },
  "routes": {
    "/api/**": {
      "path": "index.html",
      "excepts": ["/foo/**"]
    }
  }
}
STATIC_JSON
        end
      end

      it "should take precedence over a custom route" do
        response = app.get("/api/bar/")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("api")
      end

      it "should proxy if there is no matching custom route" do
        response = app.get("/proxy/bar/")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("api")
      end
    end
  end

  describe "custom headers" do
    let(:name) { "custom_headers" }

    it "should return the respected headers only for the path specified" do
      app.run do
        response = app.get("/")
        expect(response["cache-control"]).to eq("no-cache")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("index")

        response = app.get("/foo.html")
        expect(response["cache-control"]).to eq(nil)
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("foo")
      end
    end

    describe "wildcard paths" do
      let(:name) { "custom_headers_wildcard" }

      it "should add the headers" do
        app.run do
          response = app.get("/cache/")
          expect(response["Cache-Control"]).to eq("max-age=38400")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("cached index")

          response = app.get("/")
          expect(response["Cache-Control"]).to eq(nil)
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("index")
        end
      end
    end

    describe "redirect" do
      let(:name) { "custom_headers_redirect" }

      it "should add the headers" do
        response = app.get("/overlap")
        expect(response["X-Header"]).to eq("present")
        expect(response.code).to eq("302")
      end
    end

    describe "clean_urls" do
      let(:name) { "custom_headers_clean_urls" }

      it "should add the headers" do
        app.run do
          response = app.get("/foo")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("foo")
          expect(response["X-Header"]).to eq("present")

          response = app.get("/bar")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("bar")
          expect(response["X-Header"]).to be_nil
        end
      end

      it "should not add headers for .html urls" do
        response = app.get("/foo.html")
        expect(response.code).to eq("200")
        expect(response["X-Header"]).to be_nil
      end
    end

    describe "routes" do
      let(:name) { "custom_headers_routes" }

      it "should add headers" do
        app.run do
          response = app.get("/active")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("index")
          expect(response["X-Header"]).to eq("present")

          response = app.get("/foo/foo.html")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("foo")
          expect(response["X-Header"]).to be_nil
        end
      end
    end

    describe "proxies" do
      include PathHelper

      let(:name)              { "proxies" }
      let(:static_json_path)  { fixtures_path("proxies/static.json") }
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}#{path}"
    }
  },
  "headers": {
    "/api/bar/": {
      "X-Header": "present"
    }
  }
}
STATIC_JSON

          end
        end
      end

      before do
        setup_static_json.call("/foo/")
      end

      after do
        FileUtils.rm(static_json_path)
      end

      it "should proxy requests" do
        app.run do
          response = app.get("/api/bar/")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("api")
          expect(response["X-Header"]).to eq("present")

          response = app.get("/api/baz/")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("baz")
          expect(response["X-Header"]).to be_nil
        end
      end
    end
  end

  describe "debug" do
    let(:name) { "debug" }

    context "when debug is set" do
      it "should display debug info" do
        _, io_stream = app.get("/", true)
        expect(io_stream.string).to include("[info]")
      end
    end

    context "when debug isn't set" do
      let(:name) { "hello_world" }

      it "should not display debug info" do
        skip if @debug
        _, io_stream = app.get("/", true)
        expect(io_stream.string).not_to include("[info]")
      end
    end
  end
end
