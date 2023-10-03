# Redirect mobile users to the React app at /mobile
# Nest the original path under /mobile

module Middleware
  class MobileRedirect
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      browser = Browser.new(request.user_agent)

      if browser.device.mobile? && !request.path.start_with?('/mobile')
        [302, { 'Location' => "/mobile#{request.path}", 'Content-Type' => 'text/html' }, []]
      else
        @app.call(env)
      end
    end
  end
end
