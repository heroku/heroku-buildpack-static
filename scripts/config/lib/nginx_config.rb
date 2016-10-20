require 'json'
require 'uri'
require_relative 'nginx_config_util'

class NginxConfig
  DEFAULT = {
    root: "public_html/",
    encoding: "UTF-8",
    clean_urls: false,
    https_only: false,
    worker_connections: 512
  }

  def initialize(json_file)
    json = {}
    json = JSON.parse(File.read(json_file)) if File.exist?(json_file)
    json["worker_connections"] ||= ENV["WORKER_CONNECTIONS"] || DEFAULT[:worker_connections]
    json["port"] ||= ENV["PORT"] || 5000
    json["root"] ||= DEFAULT[:root]
    json["encoding"] ||= DEFAULT[:encoding]
    json["proxies"] ||= {}
    json["proxies"].each do |loc, hash|
      evaled_origin = NginxConfigUtil.interpolate(hash['origin'], ENV)
      if evaled_origin != "/"
        json["proxies"][loc].merge!("origin" => evaled_origin + "/")
      end

      uri = URI(evaled_origin)
      json["proxies"][loc]["path"] = uri.path
      uri.path = ""
      json["proxies"][loc]["host"] = uri.to_s
    end

    json["clean_urls"] ||= DEFAULT[:clean_urls]
    json["https_only"] ||= DEFAULT[:https_only]

    json["routes"] ||= {}
    json["routes"] = NginxConfigUtil.parse_routes(json["routes"])

    json["redirects"] ||= {}
    json["redirects"].each do |loc, hash|
      json["redirects"][loc].merge!("url" => NginxConfigUtil.interpolate(hash["url"], ENV))
    end

    json["error_page"] ||= nil
    json["debug"] ||= ENV['STATIC_DEBUG']
    json["prerender"] ||= nil
    json.each do |key, value|
      self.class.send(:define_method, key) { value }
    end
  end

  def context
    binding
  end
end
