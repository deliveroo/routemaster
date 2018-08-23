require "json"
require "net/http"
require "openssl"

desc "Add a token"
arg_name "token"
command :token do |c|
  c.action do | _, _, args |
    raise "token is required" if args.empty?

    token = args.first
    uri = URI("https://routemaster.deliveroo-local.com/api_tokens")

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.basic_auth("routemaster", "")
    req.body = {name: token, token: token}.to_json
    res = http.request(req)
    puts res.read_body
  end
end
