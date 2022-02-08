# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

state, city, id = uri.match(%r{/listings/([A-z0-9\-]*)\/([A-z0-9\-]*)\/([0-9]*)$}mi).captures

"#{state.downcase}/#{city.downcase}/#{id.downcase}"