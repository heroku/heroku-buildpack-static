require_relative "spec_helper"
require_relative "support/buildpack_runner"

describe "Simple" do
  let(:bp) { BuildpackRunner.new("hello_world") }

  after do
    bp.destroy
  end

  it "should serve out of public_html by default" do
    response = bp.get("/")
    expect(response.code).to eq("200")
    expect(response.body.chomp).to eq("Hello World")
  end
end
