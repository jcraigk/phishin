# Dummy OAuth server to satisfy Anthropic's MCP connector setup flow.
# The MCP server requires no authentication, but Anthropic's client
# unconditionally performs OAuth discovery (RFC 9728) and dynamic client
# registration (RFC 7591) when adding a connector. Without valid responses
# for these endpoints, the connector fails to register.
# All issued tokens are ignored by McpController — they exist only to
# complete the handshake. This may become unnecessary if Anthropic updates
# their connector flow to support no-auth MCP servers.
class McpOauthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def protected_resource
    render json: {
      resource: "#{base_url}/mcp/anthropic",
      authorization_servers: [ base_url ]
    }
  end

  def authorization_server
    render json: {
      issuer: base_url,
      authorization_endpoint: "#{base_url}/authorize",
      token_endpoint: "#{base_url}/token",
      registration_endpoint: "#{base_url}/register",
      response_types_supported: %w[code],
      grant_types_supported: %w[authorization_code client_credentials],
      token_endpoint_auth_methods_supported: %w[none],
      scopes_supported: [],
      code_challenge_methods_supported: %w[S256]
    }
  end

  def authorize
    redirect_uri = params[:redirect_uri]
    state = params[:state]
    code = SecureRandom.hex(32)

    separator = redirect_uri.include?("?") ? "&" : "?"
    redirect_to "#{redirect_uri}#{separator}code=#{code}&state=#{CGI.escape(state.to_s)}",
                allow_other_host: true
  end

  def register
    render json: {
      client_id: SecureRandom.hex(16),
      client_secret: SecureRandom.hex(32),
      client_id_issued_at: Time.now.to_i,
      client_secret_expires_at: 0,
      grant_types: %w[authorization_code client_credentials],
      token_endpoint_auth_method: "none",
      redirect_uris: params[:redirect_uris] || []
    }
  end

  def token
    render json: {
      access_token: SecureRandom.hex(32),
      token_type: "Bearer",
      expires_in: 86_400,
      scope: ""
    }
  end

  private

  def base_url
    App.base_url
  end
end
