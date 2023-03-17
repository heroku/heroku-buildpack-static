# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

def format_url(uri)
  type, subtype, state, city = uri.match(%r{/([A-z0-9-]*)-near-me(?:/([a-z]*))?/([A-z| |\-|%20]*)/([A-z| |\-|%20]*)$}i).captures
  state.gsub!(/%20| /, '-')
  city.gsub!(/%20| /, '-')

  "#{type.downcase}-near-me#{"/#{subtype.downcase}" unless subtype.nil?}/#{state.downcase}/#{city.downcase}"
end

format_url(uri)
