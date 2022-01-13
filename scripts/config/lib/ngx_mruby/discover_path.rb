# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

type, subtype = uri.match(%r{/discover/([A-z\-]*)\/*([A-z]*)$}mi).captures

if subtype
    "#{type.downcase}-near-me/#{subtype.downcase}"
else
    "#{type.downcase}-near-me"
end
