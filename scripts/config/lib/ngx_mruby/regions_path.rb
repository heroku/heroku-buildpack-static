# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

storage_type, suffix, state = uri.match(%r{\/([A-z\-]*)(-storage|-parking)\/([A-z0-9\-\p{L}'%]+)$}i).captures
types = storage_type.split('-')

if types.length > 1
  if %w[indoor outdoor covered].include? types[0]
    "#{types[1]}#{suffix}-near-me/#{types[0]}/#{state.downcase}"
  else
    # case climate-controlled storage, long term storage, long term parking
    "#{storage_type}#{suffix}-near-me/#{state.downcase}"
  end
else
  "#{types[0]}#{suffix}-near-me/#{state.downcase}"
end
