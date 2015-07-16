require 'json'
require_relative 'nginx_config_util'

class NginxConfig
  def initialize(json_file)
    json = {}
    json = JSON.parse(File.read(json_file)) if File.exist?(json_file)
    json["worker_connections"] ||= ENV["WORKER_CONNECTIONS"] || 512
    json["port"] ||= ENV["PORT"] || 5000
    json["root"] ||= "public_html/"
    json["proxies"] ||= {}
    json["proxies"].each do |loc, hash|
      if hash["origin"][-1] != "/"
        json["proxies"][loc].merge!("origin" => hash["origin"] + "/")
      end
    end
    json["clean_urls"] ||= false
    json["https_only"] ||= false
    json["routes"] ||= {}
    json["routes"] = NginxConfigUtil.parse_routes(json["routes"])
    json["redirects"] ||= {}
    json["error_page"] ||= nil
    json["debug"] ||= ENV['STATIC_DEBUG']
    json.each do |key, value|
      self.class.send(:define_method, key) { value }
    end
  end

  def context
    binding
  end
end
