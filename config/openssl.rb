env = ENV.fetch('RACK_ENV', 'development')
if env !~ /production|staging/
  unless env == 'test'
    warn "Disabling SSL certificate validation (acceptable while running tests)"
  end
  require 'openssl'
  require 'core_ext/silence_stream'
  STDERR.silence_stream do
    OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  end
end
