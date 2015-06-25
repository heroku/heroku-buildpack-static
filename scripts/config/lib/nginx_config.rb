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
    json["routes"] ||= {}
    json["routes"] = Hash[json["routes"].map {|route, target| [NginxConfigUtil.to_regex(route), target] }]
    json["redirects"] ||= {}
    json["error_page"] ||= nil
    json.each do |key, value|
      self.class.send(:define_method, key) { value }
    end
  end

  def context
    binding
  end
end
