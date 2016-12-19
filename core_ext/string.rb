class String
  def camelize(term = self)
    string = term.to_s
    string = string.gsub(/[^|\/][a-z\d]*/) { $&.capitalize }
    string.gsub!(/_(\w)?/){|m| m[1].upcase}
    string.gsub!('/', '::')
    string
  end

  def demodulize
    if i = rindex('::')
      self[(i+2)..-1]
    else
      self
    end
  end
end
