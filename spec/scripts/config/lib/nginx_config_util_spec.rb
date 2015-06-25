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
end
