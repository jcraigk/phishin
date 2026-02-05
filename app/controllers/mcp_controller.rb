class McpController < ApplicationController
  skip_before_action :verify_authenticity_token
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error

  def handle
    body = request.body.read
    response_json = server.handle_json(body)

    response.headers["Mcp-Session-Id"] = "stateless"
    render json: response_json || "{}"
  rescue JSON::ParserError => e
    render_parse_error(e.message)
  end

  private

  def handle_parse_error(exception)
    render_parse_error(exception.message)
  end

  def render_parse_error(message)
    response.headers["Mcp-Session-Id"] = "stateless"
    render json: {
      jsonrpc: "2.0",
      error: { code: -32700, message: "Parse error: #{message}" },
      id: nil
    }
  end

  def server
    Server.for_client(client_type)
  end

  def client_type
    params[:client].to_sym
  end
end
