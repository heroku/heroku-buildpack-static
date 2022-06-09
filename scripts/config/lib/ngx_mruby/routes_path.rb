# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = "/app/static.json"

config      = {}
config      = JSON.parse(File.read(USER_CONFIG)) if File.exist?(USER_CONFIG)
req         = Nginx::Request.new # defined by https://github.com/matsumotory/ngx_mruby/blob/c7682cfb4c0984a41f1a447b71ae01e1f4fcc6bf/docs/class_and_method/README.md#nginxrequest-class
uri         = req.var.uri
nginx_route = req.var.route
routes      = NginxConfigUtil.parse_routes(config["routes"])
proxies     = config["proxies"] || {}
redirects   = config["redirects"] || {}

if NginxConfigUtil.match_proxies(proxies.keys, uri) || NginxConfigUtil.match_redirects(redirects.keys, uri)
  # this will always fail, so try_files uses the callback
  uri
else
  "/#{routes[nginx_route]}"
end
