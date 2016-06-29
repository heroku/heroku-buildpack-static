require_relative "../../../spec_helper"
require_relative "../../../../scripts/config/lib/nginx_config_util"

RSpec.describe NginxConfigUtil do
  describe ".to_regex" do
    samples = [
      ['/foo/',    '/foo/'],
      ['/foo/*',   '/foo/[^/]*'],
      ['/foo/**',  '/foo/.*']
    ]

    samples.each do |(input, output)|
      it "converts #{input} to #{output}" do
        result = NginxConfigUtil.to_regex(input)
        expect(result).to eq output
      end
    end
  end

  describe ".interpolate" do
    context "single instance" do
      let(:string) { "hello ${FOO}" }
      let(:env) do
        {
          "FOO" => "world"
        }
      end
      let(:result) { "hello world" }

      it "should interpolate" do
        expect(NginxConfigUtil.interpolate(string, env)).to eq(result)
      end
    end

    context "multiple instances" do
      let(:string) { "${FOO}, ${BAR}" }
      let(:env) do
        {
          "FOO" => "hello",
          "BAR" => "world"
        }
      end
      let(:result) { "hello, world" }

      it "should interpolate" do
        expect(NginxConfigUtil.interpolate(string, env)).to eq(result)
      end
    end

    context "instance not found" do
      let(:string) { "${FOO}" }
      let(:env)    { {} }
      let(:result) { "${FOO}" }

      it "should interpolate" do
        expect(NginxConfigUtil.interpolate(string, env)).to eq(result)
      end
    end

    context "vars is nil" do
      let(:string) { "${FOO}" }
      let(:env)    { nil }
      let(:result) { "${FOO}" }

      it "should interpolate" do
        expect(NginxConfigUtil.interpolate(string, env)).to eq(result)
      end
    end

    context "complex example" do
      let(:string) { "${FOO} ${BAR} ${BAZ} ${FOO}" }
      let(:env) do
        {
          "FOO" => "foo",
          "BAZ" => "baz"
        }
      end
      let(:result) { "foo ${BAR} baz foo" }

      it "should interpolate" do
        expect(NginxConfigUtil.interpolate(string, env)).to eq(result)
      end
    end
  end
end
