require 'json'
require 'uri'
require_relative 'nginx_config_util'

class NginxConfig
  DEFAULT = {
    root: "public_html/",
    encoding: "UTF-8",
    clean_urls: false,
    https_only: false,
    basic_auth: false,
    basic_auth_htpasswd_path: "/app/.htpasswd",
    worker_connections: 512,
    resolver: "8.8.8.8",
    logging: {
      "access" => true,
      "error" => "error"
    }
  }

  def initialize(json_file)
    json = {}
    json = JSON.parse(File.read(json_file)) if File.exist?(json_file)
    json["worker_connections"] ||= ENV["WORKER_CONNECTIONS"] || DEFAULT[:worker_connections]
    json["port"] ||= ENV["PORT"] || 5000
    json["root"] ||= DEFAULT[:root]
    json["encoding"] ||= DEFAULT[:encoding]

    index = 0
    json["proxies"] ||= {}
    json["proxies"].each do |loc, hash|
      evaled_origin = NginxConfigUtil.interpolate(hash['origin'], ENV)
      uri           = URI(evaled_origin)

      json["proxies"][loc]["name"] = "upstream_endpoint_#{index}"
      cleaned_path = uri.path
      cleaned_path.chop! if cleaned_path.end_with?("/")
      json["proxies"][loc]["path"] = cleaned_path
      json["proxies"][loc]["host"] = uri.dup.tap {|u| u.path = '' }.to_s
      %w(http https).each do |scheme|
        json["proxies"][loc]["redirect_#{scheme}"] = uri.dup.tap {|u| u.scheme = scheme }.to_s
        json["proxies"][loc]["redirect_#{scheme}"] += "/" if !uri.to_s.end_with?("/")
      end
      index += 1
    end

    json["clean_urls"] ||= DEFAULT[:clean_urls]
    json["https_only"] ||= DEFAULT[:https_only]

    json["basic_auth"] = true unless ENV['BASIC_AUTH_USERNAME'].nil?
    json["basic_auth"] ||= DEFAULT[:basic_auth]
    json["basic_auth_htpasswd_path"] ||= DEFAULT[:basic_auth_htpasswd_path]

    json["routes"] ||= {}
    json["routes"] = NginxConfigUtil.parse_routes(json["routes"])

    json["redirects"] ||= {}
    json["redirects"].each do |loc, hash|
      json["redirects"][loc].merge!("url" => NginxConfigUtil.interpolate(hash["url"], ENV))
    end

    json["error_page"] ||= nil
    json["debug"] = ENV['STATIC_DEBUG']

    logging = json["logging"] || {}
    json["logging"] = DEFAULT[:logging].merge(logging)

    nameservers = []
    if File.exist?("/etc/resolv.conf")
      File.open("/etc/resolv.conf", "r").each do |line|
        next unless md = line.match(/^nameserver\s*(\S*)/)
        nameservers << md[1]
      end
    end
    nameservers << [DEFAULT[:resolver]] unless nameservers.empty?
    json["resolver"] = nameservers.join(" ")

    json.each do |key, value|
      self.class.send(:define_method, key) { value }
    end
  end

  def context
    binding
  end
end
