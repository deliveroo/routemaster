# Adapted from
# activesupport/lib/active_support/core_ext/kernel/reporting.rb, line 44
class IO
  def silence_stream(&block)
    old_stream = dup
    self.reopen('/dev/null')
    self.sync = true
    yield
  ensure
    reopen(old_stream)
    old_stream.close
  end
end
