require "fileutils"
require_relative "spec_helper"
require_relative "support/app_runner"
require_relative "support/router_runner"
require_relative "support/buildpack_builder"
require_relative "support/router_builder"
require_relative "support/proxy_builder"
require_relative "support/proxy_runner"
require_relative "support/path_helper"

RSpec.describe "Simple" do
  before(:all) do
    @debug = false
    BuildpackBuilder.new(@debug, ENV['CIRCLECI'])
    RouterBuilder.new(@debug, ENV['CIRCLECI'])
    ProxyBuilder.new(@debug, ENV["CIRCLECI"])
  end

  after do
    app.destroy
  end

  let(:proxy) { nil }
  let(:app)   { AppRunner.new(name, proxy, env, @debug, !ENV['CIRCLECI']) }

  let(:name)  { "hello_world" }
  let(:env)   { Hash.new }

  it "should serve out of public_html by default" do
    response = app.get("/")
    expect(response.code).to eq("200")
    expect(response.body.chomp).to eq("Hello World")
  end

  describe "mime/types" do
    let(:name) { "mime_types_json" }

    context "json" do
      it "should serve json as application/json content type" do
        response = app.get("/foo.json")
        expect(response.code).to eq("200")
        expect(response["Content-Type"]).to eq("application/json")
      end
    end
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
      app.run do
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

    context "when there is a conflict" do
      let(:name) { "clean_urls_conflict" }


      it "should be able to handle when a directory and .html file share the same name" do
        app.run do
          response = app.get("/foo/bar")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("bar")

          response = app.get("/foo")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("foobar")
        end
      end
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
      expect(response["location"]).to eq("http://#{RouterRunner::HOST_IP}/")
    end

    context "interpolation" do
      let(:name) { "redirects_interpolation" }

      let(:env)  {
        { "INTERPOLATED_URL" => "/interpolation.html" }
      }

      it "should redirect using interpolated urls" do
        response = app.get("/old/interpolation")
        expect(response.code).to eq("302")
        expect(response["location"]).to eq("http://#{RouterRunner::HOST_IP}/interpolation.html")
      end
    end

    context "https_only" do
      let(:name) { "redirects_https_only" }

      it "should redirect to https first" do
        response = app.get("/old/gone")
        expect(response.code).to eq("301")
        expect(response["location"]).to eq("https://#{RouterRunner::HOST_IP}/old/gone")
      end
    end
  end

  describe "https only" do
    let(:name) { "https_only" }

    it "should redirect http to https" do
      app.run do
        response = app.get("/foo.html")
        expect(response.code).to eq("301")
        uri = URI(response['Location'])
        expect(uri.scheme).to eq("https")
        expect(uri.path).to eq("/foo.html")

        response = app.get(uri)
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("foobar")
      end
    end

    context "CRLF HTTP Header injection" do
      let(:cookie) { "malicious=1" }

      it "should not expose cookie" do
        app.run do
          response = app.get("/foo.html#{URI.escape("\r\nSet-Cookie: #{cookie}")}")
          expect(response['set-cookie']).not_to eq(cookie)
        end
      end
    end
  end

  describe "basic_auth" do
    context "static.json without basic_auth key" do
      let(:name) { "hello_world" }

      let(:env) {
        {
          "BASIC_AUTH_USERNAME" => "test",
          "BASIC_AUTH_PASSWORD" => "$apr1$Dnavu2z9$ZFxQn/mXVQoeYGD.tA2bW/"
        }
      }

      it "should require authentication" do
        response = app.get("/index.html")
        expect(response.code).to eq("401")
      end
    end

    context "static.json with basic_auth key and .htpasswd" do
      let(:name) { "basic_auth" }

      let(:env) {
        {
          "BASIC_AUTH_USERNAME" => "test",
          "BASIC_AUTH_PASSWORD" => "$apr1$/pb2/xQR$cn7UPcTOLymIH1ZMe.NfO."
        }
      }

      it "should require authentication" do
        response = app.get("/foo.html")
        expect(response.code).to eq("401")
      end
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
    let(:proxy)             { true }
    let(:static_json_path)  { fixtures_path("proxies/static.json") }
    let(:setup_static_json) do
      Proc.new do |path|
        File.open(static_json_path, "w") do |file|
          file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://#{@proxy_ip_address}#{path}"
    }
  }
}
STATIC_JSON

        end
      end
    end

    before do
      @proxy_ip_address = app.proxy.ip_address
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
      "origin": "http://#{@proxy_ip_address}/foo"
    },
    "/proxy/": {
      "origin": "http://#{@proxy_ip_address}/foo"
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

    context "https_only" do
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "http://#{@proxy_ip_address}#{path}"
    }
  },
  "https_only": true
}
STATIC_JSON
          end
        end
      end

      before do
        setup_static_json.call("/")
      end

      it "should not redirect direct to the proxy" do
        response = app.get("/api/bar")
        expect(response.code).to eq("301")
        expect(response["Location"]).to eq("https://#{RouterRunner::HOST_IP}/api/bar")
      end
    end

    context "env var substitution" do
      let(:proxy) do
        <<CONFIG_RU
get "/foo/bar/" do
  "api"
end
CONFIG_RU
      end

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
          "PROXY_HOST" => "${PROXY_IP_ADDRESS}"
        }
      end

      it "should proxy requests" do
        response = app.get("/api/bar/")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("api")
      end
    end

    context "proxy to a pathed URI" do
      let(:proxy) do
        <<PROXY
get "/foo/hello" do
  "hello"
end

get "/foo/http_redirect/" do
  uri = URI("http://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end

get "/foo/https_redirect/" do
  uri = URI("https://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end
PROXY
      end

      let(:proxy_scheme) { "http" }
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_origin_no_slash/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
    },
    "/api_no_slash_origin_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
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

      it "proxies properly" do
        response = app.get("/api/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")
      end

      it "should handle redirects regardless of scheme" do
        app.run do
          response = app.get("/api/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)
        end
      end
    end

    context "proxy to a domain" do
      let(:proxy) do
          <<PROXY
get "/hello" do
  "hello"
end

get "/http_redirect/" do
  uri = URI("http://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end

get "/https_redirect/" do
  uri = URI("https://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end
PROXY
      end

      let(:proxy_scheme) { "http" }
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_origin_no_slash/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
    },
    "/api_no_slash_origin_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
    }
  }
}
STATIC_JSON
          end
        end
      end

      before do
        setup_static_json.call("/")
      end

      it "proxies properly" do
        response = app.get("/api/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")
      end

      it "should handle redirects regardless of scheme" do
        app.run do
          response = app.get("/api/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)
        end
      end
    end

    context "fallback" do
      let(:proxy) do
          <<PROXY
get "/hello" do
  "hello"
end

get "/http_redirect/" do
  uri = URI("http://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end

get "/https_redirect/" do
  uri = URI("https://\#{request.host}/foo/redirect")
  redirect URI(uri), 307
end
PROXY
      end

      let(:proxy_scheme) { "http" }
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
    },
    "/api_origin_no_slash/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
    },
    "/api_no_slash_origin_no_slash": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path.chop}"
    }
  },
  "routes": {
    "/**": "index.html"
  }
}
STATIC_JSON
          end
        end
      end

      before do
        setup_static_json.call("/")
      end

      it "should proxy properly" do
        response = app.get("/api/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")

        response = app.get("/api_no_slash_origin_no_slash/hello")
        expect(response.code).to eq("200")
        expect(response.body.chomp).to eq("hello")
      end

      it "should handle redirects regardless of scheme" do
        app.run do
          response = app.get("/api/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/http_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)

          response = app.get("/api_no_slash_origin_no_slash/https_redirect/")
          expect(response.code).to eq("307")
          expect(response["Location"]).not_to include(@proxy_ip_address)
        end
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
      let(:proxy_scheme)      { "http" }
      let(:static_json_path)  { fixtures_path("proxies/static.json") }
      let(:proxy) do
        <<PROXY
get "/foo/bar/" do
  "api"
end

get "/foo/baz/" do
  "baz"
end
PROXY
      end
      let(:setup_static_json) do
        Proc.new do |path|
          File.open(static_json_path, "w") do |file|
            file.puts <<STATIC_JSON
{
  "proxies": {
    "/api/": {
      "origin": "#{proxy_scheme}://#{@proxy_ip_address}#{path}"
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
        @proxy_ip_address = app.proxy.ip_address
        setup_static_json.call("/foo")
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

  describe "logs" do
    let(:name) { "info" }

    context "when error log is set to info" do
      it "should display info logs" do
        _, io_stream = app.get("/", true)
        expect(io_stream.string).to include("[info]")
      end
    end

    context "override debug when env var is set" do
      let(:app) { AppRunner.new(name, proxy, env, true, !ENV['CIRCLECI']) }
      let(:name) { "hello_world" }

      it "should display debug info" do
        _, io_stream = app.get("/", true)
        expect(io_stream.string).to include("[info]")
      end
    end

    context "should default to normal logging" do
      let(:name) { "hello_world" }

      it "should not display debug info and display access logs" do
        skip if @debug
        _, io_stream = app.get("/", true)
        expect(io_stream.string).not_to include("[info]")
        expect(io_stream.string).to include("GET /")
      end
    end

    context "turn off all logging" do
      let(:name) { "logging_access_off" }

      it "should not log access" do
        _, io_stream = app.get("/", true)
        expect(io_stream.string).not_to include("[info]")
        expect(io_stream.string).not_to include("GET /")
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

          response = app.get("/hello")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("hello world")

          response = app.get("/foo")
          expect(response.code).to eq("200")
          expect(response.body.chomp).to eq("foo")
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
end
