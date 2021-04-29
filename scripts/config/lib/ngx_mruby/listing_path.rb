# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

city, state, id = uri.match(%r{/rentals/([A-z\-'].*)--([A-z\-'].*)-self-storage-space-([0-9].*)$}i).captures

"#{state.downcase}/#{city.downcase}/#{id.downcase}"
