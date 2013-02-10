# Phish.net Ruby API Wrapper, Stephen Blackstone <sblackstone@gmail.com>
 
require 'net/http'
require 'net/https'
require 'json'
require 'openssl'
require 'pp'
 
class PNet
  BASE_URL =  "https://api.phish.net/endpoint.php"
 
  def initialize(api_key)
    @options = {
      'api'    => "2.0",
      'apikey' => api_key,
      'format' => "json"
    }
    @url = URI.parse(BASE_URL)  
  end
 
  def perform_action(opts)
    url = URI.parse(BASE_URL)
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data(@options.merge(opts))
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Comodo certs still need extra cert chain?
    res = http.start {|http| http.request(request) }  
    case res
    when Net::HTTPSuccess
      begin
        return JSON::Parser.new(res.body).parse
      rescue
        raise "Server or Parse Error"
      end
    else
      raise "Server Error"
    end
  end
 
  public
  # Will cause the Authkey to be used from this point forward.
  def api_authorize(opts = {})
    opts['method'] = "pnet.api.authorize"
    auth = perform_action(opts)
    if auth["success"] == 1
      @options["authkey"] = auth["authkey"]
      return true
    else
      raise "Authentication Failure"
    end
  end
 
  # Forget the auth key.   
  def deauthorize
    @options.delete("authkey")
  end
 
 
  # Call any method with pnet.remote_method_name(:option1 => val1, :option2 => val2)
  def method_missing(m, *args, &block)
    action =  "pnet_#{m}".tr('_', '.')
    opts = args.first || {}
    opts.merge!({'method' => action})
    perform_action(opts)
  end
 
end