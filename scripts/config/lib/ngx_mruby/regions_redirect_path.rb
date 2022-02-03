# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

if uri.include?("indoor") || uri.include?("outdoor") || uri.include?("covered")
    state, type, subtype = uri.match(%r{/regions/([A-z0-9\-\p{L}'%]*)\/([A-z0-9\-\p{L}'%]*)\/([A-z0-9\-\p{L}'%]*)$}mi).captures
    "#{type.downcase}-near-me/#{subtype}/#{state}"
else
    state, type = uri.match(%r{/regions/([A-z0-9\-\p{L}'%]*)\/([A-z0-9\-\p{L}'%]*)$}mi).captures
    "#{type.downcase}-near-me/#{state}"
end
