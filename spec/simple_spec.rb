require "fileutils"
require_relative "spec_helper"
require_relative "support/app_runner"
require_relative "support/buildpack_builder"
require_relative "support/path_helper"

RSpec.describe "Simple" do
  before(:all) do
    @debug = true
    BuildpackBuilder.new(@debug, ENV['CIRCLECI'])
  end

  after do
    app.destroy
  end

  let(:app)  { AppRunner.new(name, env, @debug, ENV['CIRCLECI']) }

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

      response = app.get("/bar")
      expect(response.code).to eq("301")
      response = app.get(response["Location"])
      expect(response.code).to eq("200")
      expect(response.body.chomp).to eq("bar")
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
  end

  describe "redirects" do
    let(:name) { "redirects" }

    it "should redirect and respect the http code & remove the port" do
      response = app.get("/old/gone")
      expect(response.code).to eq("302")
      expect(response["location"]).to eq("http://#{AppRunner::HOST_IP}/")
    end

    context "interpolation" do
      let(:name) { "redirects_interpolation" }

      let(:env)  {
        { "INTERPOLATED_URL" => "/interpolation.html" }
      }

      it "should redirect using interpolated urls" do
        response = app.get("/old/interpolation")
        expect(response.code).to eq("302")
        expect(response["location"]).to eq("http://#{AppRunner::HOST_IP}/interpolation.html")
      end
    end
  end

  describe "https only" do
    let(:name) { "https_only" }

    it "should redirect http to https" do
      response = app.get("/foo")
      expect(response.code).to eq("301")
      uri = URI(response['Location'])
      expect(uri.scheme).to eq("https")
      expect(uri.path).to eq("/foo")
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
    "/api/**": "index.html"
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

    context "env var substitution" do
      before do
        File.open(static_json_path, "w") do |file|
          file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://${PROXY_HOST}/foo"
    }
  }
}
STATIC_JSON
        end
      end

      let(:env) do
        {
          "PROXY_HOST" => "#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}"
        }
      end

      it "should proxy requests" do
        response = app.get("/api/bar/")
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
        expect(response["X-Foo"]).to eq("true")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("foo")
      end
    end

    describe "conflicting headers" do
      let(:name) { "custom_headers_no_append" }

      it "should not append headers" do
        response = app.get("/foo.html")
        expect(response["X-Foo"]).to eq("true")
        expect(response["X-Bar"]).to eq(nil)
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

  describe "ordering" do
    let(:name) { "ordering" }

    it "should serve files in the correct order" do
      app.run do
        response = app.get("/assets/app.js")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("{}")

        response = app.get("/old/gone")
        expect(response.code).to eq("302")
        expect(app.get(response["location"]).body.chomp).to eq("goodbye")

        response = app.get("/foo")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello world")
      end
    end

    context "https" do
      let(:name) { "ordering_https" }

      it "should serve files in the correct order" do
        app.run do
          response = app.get("/assets/app.js")
          expect(response.code).to eq("301")

          uri = URI(response['location'])
          expect(uri.path).to eq("/assets/app.js")
          expect(uri.scheme).to eq("https")
        end
      end

    end

    context "clean_urls" do
      let(:name) { "ordering_clean_urls" }

      it "should honor clean urls" do
        app.run do
          response = app.get("/gone")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("goodbye")

          response = app.get("/gone.html")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("goodbye")

          response = app.get("/bar")
          expect(response.code).to eq("301")
          response = app.get(response["Location"])
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("bar")

          response = app.get("/assets/app.js")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("{}")

          response = app.get("/old/gone")
          expect(response.code).to eq("302")
          expect(app.get(response["location"]).body.chomp).to eq("goodbye")

          response = app.get("/foo")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("hello world")
        end
      end
    end

    context "without custom routes" do
      let(:name) { "ordering_without_custom_routes" }

      it "should still respect ordering" do
        app.run do
          response = app.get("/gone.html")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("goodbye")

          response = app.get("/no_redirect.html")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("no_redirect")

          response = app.get("/bar")
          expect(response.code).to eq("301")
          response = app.get(response["Location"])
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("bar")

          response = app.get("/assets/app.js")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("{}")

          response = app.get("/old/gone")
          expect(response.code).to eq("302")
          expect(app.get(response["location"]).body.chomp).to eq("goodbye")

          response = app.get("/foo")
          expect(response.code).to eq("404")
        end
      end
    end

    context "with clean urls without custom routes" do
      let(:name) { "ordering_with_clean_urls_without_custom_routes" }

      it "should still respect ordering" do
        app.run do
          response = app.get("/gone")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("goodbye")

          response = app.get("/gone.html")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("goodbye")

          response = app.get("/no_redirect")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("no_redirect")

          response = app.get("/bar")
          expect(response.code).to eq("301")
          response = app.get(response["Location"])
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("bar")

          response = app.get("/assets/app.js")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("{}")

          response = app.get("/old/gone")
          expect(response.code).to eq("302")
          expect(app.get(response["location"]).body.chomp).to eq("goodbye")

          response = app.get("/foo")
          expect(response.code).to eq("404")
        end
      end
    end
  end

  describe "env vars" do
    let(:env)  do
      {
        "SECRET"            => "OMG",
        "HEROKU_STATIC_FOO" => "f00",
        "HEROKU_STATIC_BAR" => "b4r"
      }
    end

    context "simple" do
      context "env.js" do
        let(:name) { "env_vars" }

        it "should setup envs accessible to the frontend app" do
          response = app.get("/--/env.js")

          expect(response.code).to eq("200")

          app.run do
            app.test_js(name: "env vars get set", num: 3, path: "/index.html", content: <<-JS)
  test.assertEval(function() {
    return $('#foo').text() === "#{env["HEROKU_STATIC_FOO"]}"
  }, "#foo has changed values");
  test.assertEval(function() {
    return $('#bar').text() === "#{env["HEROKU_STATIC_BAR"]}"
  }, "#bar has changed values");
  test.assertEval(function() {
    return $('#secret').text() === "Replace Me"
  }, "#secret has not changed values");
            JS
          end
        end
      end

      context "env.json" do
        let(:name) { "env_vars_json" }

        it "should setup envs accessible to the frontend app" do
          response = app.get("/--/env.json")

          expect(response.code).to eq("200")

          app.run do
            app.test_js(name: "env vars get set", num: 3, path: "/index.html", content: <<-JS)
  test.assertEval(function() {
    return $('#foo').text() === "#{env["HEROKU_STATIC_FOO"]}"
  }, "#foo has changed values");
  test.assertEval(function() {
    return $('#bar').text() === "#{env["HEROKU_STATIC_BAR"]}"
  }, "#bar has changed values");
  test.assertEval(function() {
    return $('#secret').text() === "Replace Me"
  }, "#secret has not changed values");
            JS
          end
        end
      end
    end

    context "custom routes" do
      context "env.js" do
        let(:name) { "env_vars_custom_routes" }

        it "should setup envs accessible to the frontend app" do
          response = app.get("/--/env.js")

          expect(response.code).to eq("200")

          app.run do
            app.test_js(name: "env vars get set", num: 3, path: "/foo", content: <<-JS)
  test.assertEval(function() {
    return $('#foo').text() === "#{env["HEROKU_STATIC_FOO"]}"
  }, "#foo has changed values");
  test.assertEval(function() {
    return $('#bar').text() === "#{env["HEROKU_STATIC_BAR"]}"
  }, "#bar has changed values");
  test.assertEval(function() {
    return $('#secret').text() === "Replace Me"
  }, "#secret has not changed values");
            JS
          end
        end
      end

      context "env.json" do
        let(:name) { "env_vars_json_custom_routes" }

        it "should setup envs accessible to the frontend app" do
          response = app.get("/--/env.json")

          expect(response.code).to eq("200")

          app.run do
            app.test_js(name: "env vars get set", num: 3, path: "/foo", content: <<-JS)
  test.assertEval(function() {
    return $('#foo').text() === "#{env["HEROKU_STATIC_FOO"]}"
  }, "#foo has changed values");
  test.assertEval(function() {
    return $('#bar').text() === "#{env["HEROKU_STATIC_BAR"]}"
  }, "#bar has changed values");
  test.assertEval(function() {
    return $('#secret').text() === "Replace Me"
  }, "#secret has not changed values");
            JS
          end
        end
      end

    end

  end
end
