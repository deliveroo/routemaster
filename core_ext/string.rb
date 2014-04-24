class String
  def camelize(term = self, uppercase_first_letter = true)
    string = term.to_s
    string = string.sub(/^[a-z\d]*/) { $&.capitalize }
    string.gsub!('/', '::')
    string
  end
end
