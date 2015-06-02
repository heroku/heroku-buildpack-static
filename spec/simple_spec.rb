require_relative "spec_helper"
require_relative "support/app_runner"
require_relative "support/buildpack_builder"

describe "Simple" do
  before(:all) do
    @debug = false
    BuildpackBuilder.new(@debug)
  end
  let(:app) { AppRunner.new("hello_world", @debug) }

  after do
    app.destroy
  end

  it "should serve out of public_html by default" do
    response = app.get("/")
    expect(response.code).to eq("200")
    expect(response.body.chomp).to eq("Hello World")
  end
end
