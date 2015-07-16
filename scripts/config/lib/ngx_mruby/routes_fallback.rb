# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = "/app/static.json"

config    = {}
config    = JSON.parse(File.read(USER_CONFIG)) if File.exist?(USER_CONFIG)
req       = Nginx::Request.new
uri       = req.var.uri
proxies   = config["proxies"] || {}
redirects = config["redirects"] || {}

if proxy = NginxConfigUtil.match_proxies(proxies.keys, uri)
  "@#{proxy}"
elsif redirect = NginxConfigUtil.match_redirects(redirects.keys, uri)
  "@#{redirect}"
else
  "@404"
end
