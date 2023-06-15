# frozen_string_literal: true

# ghetto require, since mruby doesn't have require
eval(File.read('/app/bin/config/lib/nginx_config_util.rb'))

USER_CONFIG = '/app/static.json'

req         = Nginx::Request.new
uri         = req.var.uri

def updated_state(abbr_state)
    state_map = {
        "al" => "alabama",
        "ak" => "alaska",
        "az" => "arizona",
        "ar" => "arkansas",
        "ca" => "california",
        "co" => "colorado",
        "ct" => "connecticut",
        "de" => "delaware",
        "dc" => "district-of-columbia",
        "fl" => "florida",
        "ga" => "georgia",
        "hi" => "hawaii",
        "id" => "idaho",
        "il" => "illinois",
        "in" => "indiana",
        "ia" => "iowa",
        "ks" => "kansas",
        "ky" => "kentucky",
        "la" => "louisiana",
        "me" => "maine",
        "md" => "maryland",
        "ma" => "massachusetts",
        "mi" => "michigan",
        "mn" => "minnesota",
        "ms" => "mississippi",
        "mo" => "missouri",
        "mt" => "montana",
        "ne" => "nebraska",
        "nv" => "nevada",
        "nh" => "new-hampshire",
        "nj" => "new-jersey",
        "nm" => "new-mexico",
        "ny" => "new-york",
        "nc" => "north-carolina",
        "nd" => "north-dakota",
        "oh" => "ohio",
        "ok" => "oklahoma",
        "or" => "oregon",
        "pa" => "pennsylvania",
        "ri" => "rhode-island",
        "sc" => "south-carolina",
        "sd" => "south-dakota",
        "tn" => "tennessee",
        "tx" => "texas",
        "ut" => "utah",
        "vt" => "vermont",
        "va" => "virginia",
        "wa" => "washington",
        "wv" => "west-virginia",
        "wi" => "wisconsin",
        "wy" => "wyoming",
    }
    if state_map.key?(abbr_state)
        return state_map[abbr_state]
    else
        return abbr_state
    end
end

def correct_state(uri)
    type, subtype, state, city = uri.match(%r{/([A-z0-9-]*)-near-me(?:/(indoor|outdoor|covered))?/([A-z| |\-|%20|\+]*)(/[A-z| |\-|%20|\+]*)*$}i).captures
    state.gsub!(/%20| |\+/, '-')
    city.gsub!(/%20| |\+/, '-')

    "#{type.downcase}-near-me#{"/#{subtype.downcase}" unless subtype.nil?}/#{updated_state(state.downcase)}#{"/#{city.downcase}" unless city.nil?}"
end

correct_state(uri)
