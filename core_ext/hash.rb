class Hash
  def symbolize_keys
    dup.tap do |h|
      h.keys.each do |key|
        h[(key.to_sym rescue key) || key] = h.delete(key)
      end
    end
  end
end
