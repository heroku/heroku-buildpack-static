# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

storage_type, suffix, state = uri.match(%r{\/([A-z\-]*)(-storage|-parking)\/([A-z\-]+)$}i).captures
types = storage_type.split('-')

if types.length > 1
  if %w[indoor outdoor covered].include? types[0]
    "#{state.downcase}/#{types[1]}#{suffix}/#{types[0]}"
  else
    # case climate-controlled storage, long term storage, long term parking
    "#{state.downcase}/#{storage_type}#{suffix}"
  end
else
  "#{state.downcase}/#{types[0]}#{suffix}"
end
