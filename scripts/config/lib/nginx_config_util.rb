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
end
