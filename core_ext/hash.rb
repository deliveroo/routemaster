class Hash
  def symbolize_keys
    dup.tap do |h|
      h.keys.each do |key|
        h[(key.to_sym rescue key) || key] = h.delete(key)
      end
    end
  end

  def map_values
    dup.tap do |h|
      h.keys.each do |key|
        h[key] = yield h.delete(key)
      end
    end
  end
end
