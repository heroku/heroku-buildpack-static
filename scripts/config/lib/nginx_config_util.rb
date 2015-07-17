module NginxConfigUtil
  def self.to_regex(path)
    segments = []
    while !path.empty?
      if path[0...2] == '**'
        segments << '.*'
        path = path[2..-1]
      elsif path[0...1] == '*'
        segments << '[^/]*'
        path = path[1..-1]
      else
        next_star = path.index("*") || path.length
        segments << Regexp.escape(path[0...next_star])
        path = path[next_star..-1]
      end
    end
    segments.join
  end

  def self.parse_routes(json)
    routes = json.map do |route, target|
      path =
        if target.is_a?(String)
          {"path" => target}
        else
          {
            "path"    => target["path"],
            "excepts" => target["excepts"].map {|except| to_regex(except) }
          }
        end

      [to_regex(route), path]
    end

    Hash[routes]
  end
end
