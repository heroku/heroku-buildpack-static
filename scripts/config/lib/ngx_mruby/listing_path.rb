# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

city, state, id = uri.match(%r{/rentals/([A-z0-9\-\p{L}'%].*)--([^\-][A-z0-9\-\p{L}'%].*)-self-storage-space-([0-9].*)$}mi).captures

"#{state.downcase}/#{city.downcase}/#{id.downcase}"
