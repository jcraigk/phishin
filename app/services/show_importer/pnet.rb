# frozen_string_literal: true
class ShowImporter::PNet
  BASE_URL = 'https://api.phish.net/endpoint.php'

  def initialize(api_key)
    @options = {
      'api' => '2.0',
      'apikey' => api_key,
      'format' => 'json'
    }
    @url = URI.parse(BASE_URL)
  end

  def perform_action(opts) # rubocop:disable Metrics/AbcSize
    url = URI.parse(BASE_URL)
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data(@options.merge(opts))
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    res = http.start { |ht| ht.request(request) }
    raise 'Server Error' unless res.code.to_i == 200

    JSON[res.body]
  end

  # Will cause the Authkey to be used from this point forward.
  def api_authorize(opts = {})
    opts['method'] = 'pnet.api.authorize'
    auth = perform_action(opts)
    raise 'Authentication Failure' unless auth['success'] == 1

    @options['authkey'] = auth['authkey']
    true
  end

  # Forget the auth key.
  def deauthorize
    @options.delete('authkey')
  end

  def method_missing(method, *args, &_block) # rubocop:disable Style/MethodMissingSuper
    opts = args.first || {}
    opts['method'] = "pnet_#{method}".tr('_', '.')
    perform_action(opts)
    # super
  end
end
