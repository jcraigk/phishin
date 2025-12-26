class McpController < ApplicationController
  skip_before_action :verify_authenticity_token

  def handle
    body = request.body.read
    response_json = Server.instance.handle_json(body)

    response.headers["Mcp-Session-Id"] = "stateless"
    render json: response_json || "{}"
  end
end
