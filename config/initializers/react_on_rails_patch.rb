# Patch react_on_rails for connection_pool 3.0 compatibility
# TODO: Remove when react_on_rails fixes ConnectionPool.new call
require "react_on_rails/server_rendering_pool/ruby_embedded_java_script"

if defined?(ConnectionPool::VERSION) &&
   Gem::Version.new(ConnectionPool::VERSION) >= Gem::Version.new("3.0")
  module ReactOnRails
    module ServerRenderingPool
      class RubyEmbeddedJavaScript
        def self.reset_pool
          options = {
            size: ReactOnRails.configuration.server_renderer_pool_size,
            timeout: ReactOnRails.configuration.server_renderer_timeout
          }
          @js_context_pool = ConnectionPool.new(**options) { create_js_context }
        end
      end
    end
  end
end
