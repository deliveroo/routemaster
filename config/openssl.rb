if ENV.fetch('RACK_ENV', 'development') !~ /production|staging/
  require 'openssl'
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
end
