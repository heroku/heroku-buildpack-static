require_relative "spec_helper"
require_relative "support/app_runner"
require_relative "support/buildpack_builder"

RSpec.describe "Simple" do
  before(:all) do
    @debug = false
    BuildpackBuilder.new(@debug)
  end

  after do
    app.destroy
  end

  let(:app)  { AppRunner.new(name, @debug) }

  let(:name) { "hello_world" }

  it "should serve out of public_html by default" do
    response = app.get("/")
    expect(response.code).to eq("200")
    expect(response.body.chomp).to eq("Hello World")
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

  describe "redirects" do
    let(:name) { "redirects" }

    it "should redirect and respect the http code" do
      response = app.get("/old/gone")
      expect(response.code).to eq("302")
      expect(response["location"]).to eq("http://#{AppRunner::HOST_IP}:#{AppRunner::HOST_PORT}/")
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
end
