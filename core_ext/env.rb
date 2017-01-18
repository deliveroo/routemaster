module EnvIndirectFetch
  def ifetch(name)
    value = fetch(name)
    if value =~ /^[A-Z][A-Z_]+$/
      fetch(value)
    else
      value
    end
  end
end

ENV.extend(EnvIndirectFetch)
