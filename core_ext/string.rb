class String
  def camelize(term = self)
    string = term.to_s
    string = string.gsub(/[^|\/][a-z\d]*/) { $&.capitalize }
    string.gsub!(/_(\w)?/){|m| m[1].upcase}
    string.gsub!('/', '::')
    string
  end
end
