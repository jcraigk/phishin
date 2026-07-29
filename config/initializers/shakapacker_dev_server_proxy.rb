# rack-proxy 1.0 refuses backends derived from the Host header unless the app
# opts in, which breaks Shakapacker's dev server proxy: every /packs/* request
# returns an empty 502. Shakapacker builds its backend from the Host header, so
# it needs the opt-in.
#
# Rather than allow any Host-derived backend, this restricts the proxy to the
# host and port from config/shakapacker.yml, so it can only ever reach the local
# dev server. Remove this once Shakapacker supports rack-proxy 1.0 directly.
if Rails.env.development? && defined?(Shakapacker::DevServerProxy)
  module ShakapackerDevServerProxyBackendGuard
    def initialize(app = nil, opts = {})
      super(app, opts.merge(allow_dynamic_backend: true))
    end

    # Consulted on every request with the resolved backend.
    def backend_allowed?(backend)
      backend.host == dev_server.host && backend.port == dev_server.port
    end
  end

  Shakapacker::DevServerProxy.prepend(ShakapackerDevServerProxyBackendGuard)
end
