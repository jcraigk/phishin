class McpController < ApplicationController
  skip_before_action :verify_authenticity_token

  def handle
    body = request.body.read
    response_json = server.handle_json(body)

    response.headers["Mcp-Session-Id"] = "stateless"
    render json: response_json || "{}"
  end

  private

  def server
    Server.for_client(client_type)
  end

  def client_type
    case request.path
    when %r{^/mcp/openai}
      :openai
    else
      :default
    end
  end
end
