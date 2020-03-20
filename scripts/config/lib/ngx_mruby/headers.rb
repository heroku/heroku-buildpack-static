# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = "/app/static.json"
ENV_CONFIG  = "/app/config/.env.json"

envs   = {}
config = {}
config = JSON.parse(File.read(USER_CONFIG)) if File.exist?(USER_CONFIG)
envs   = JSON.parse(File.read(ENV_CONFIG)) if File.exist?(ENV_CONFIG)
req    = Nginx::Request.new
uri    = req.var.uri

if config["headers"]
  config["headers"].to_a.reverse.each do |route, header_hash|
    if Regexp.compile("^#{NginxConfigUtil.to_regex(NginxConfigUtil.interpolate(route.dup, envs))}$") =~ uri
      header_hash.each do |key, value|
        # value must be a string
        req.headers_out[NginxConfigUtil.interpolate(key.dup, envs)] = NginxConfigUtil.interpolate(value.to_s, envs)
      end
      break
    end
  end
end
