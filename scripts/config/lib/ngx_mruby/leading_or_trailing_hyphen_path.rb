# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

def correct_path(uri)
  uri.gsub(/\/(\-+)/, '/').gsub(/(\-+)(?=\/|$)/, '')
end

correct_path(uri)
