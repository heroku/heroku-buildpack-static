# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

city, state, type = uri.match(%r{\/([A-z\-']*)--([A-z\-']*)-(garages|long-term-parking|monthly-parking|self-storage|driveway-parking)$}i).captures

"#{state.downcase}/#{city.downcase}/#{type.downcase}"
