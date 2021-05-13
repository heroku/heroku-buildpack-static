# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

city, state, type, subtype = uri.match(%r{\/([A-z0-9\-\p{L}'%]*)--([A-z0-9\-\p{L}'%]*)--([A-z\-]*)\/*([A-z]*)$}mi).captures

"#{state.downcase}/#{city.downcase}/#{type.downcase}#{ "/#{subtype}" unless subtype.empty? }"
