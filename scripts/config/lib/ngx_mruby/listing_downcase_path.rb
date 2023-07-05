# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

path = uri.match(%r{/storage-units-near-me/(.*)$}mi).captures

path.downcase.gsub(/%20| |\+/, '-')