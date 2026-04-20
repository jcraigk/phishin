class ApplicationController < ActionController::Base
  AGENT_LINK_HEADERS = [
    %(</llms.txt>; rel="llms"; type="text/plain"),
    %(</sitemap.xml>; rel="sitemap"; type="application/xml"),
    %(</.well-known/mcp/server-card.json>; rel="mcp_server"; type="application/json"),
    %(</.well-known/agent-card.json>; rel="agent_card"; type="application/json"),
    %(</.well-known/agent-skills/index.json>; rel="agent_skills"; type="application/json"),
    %(</.well-known/api-catalog>; rel="api-catalog"; type="application/linkset+json"),
    %(</api/v2/swagger_doc>; rel="service-desc"; type="application/openapi+json"),
    %(</api-docs>; rel="service-doc"; type="text/html")
  ].freeze

  def application
    add_agent_link_headers

    if prefers_markdown?
      render_markdown_view
      return
    end

    @meta = MetaTagService.call(request.path)
    @react_props = {
      # OAuth login
      jwt: session[:jwt],
      username: session[:username],
      usernameUpdatedAt: session[:username_updated_at],
      email: session[:email],
      alert: flash[:alert],

      # Misc
      usernameCooldown: App.username_cooldown.to_i,

      # Third party integrations
      mapboxToken: ENV.fetch("MAPBOX_TOKEN", nil)
    }

    # Clear session after OAuth redirect
    session.delete(:jwt)
    session.delete(:username)
    session.delete(:username_updated_at)
    session.delete(:email)

    # Render layout + React app
    render html: "", layout: "application", status: @meta[:status]
  end

  private

  def add_agent_link_headers
    existing = response.headers["Link"]
    response.headers["Link"] = [ existing, AGENT_LINK_HEADERS.join(", ") ].compact.join(", ")
    response.headers["Vary"] = [ response.headers["Vary"], "Accept" ].compact.join(", ")
  end

  def prefers_markdown?
    accept = request.headers["Accept"].to_s.downcase.strip
    return false if accept.empty? || accept == "*/*"
    # Only serve markdown when the client explicitly leads its Accept header
    # with text/markdown (avoids hijacking normal browser requests).
    first_type = accept.split(",").first.to_s.split(";").first.to_s.strip
    first_type == "text/markdown"
  end

  def render_markdown_view
    markdown = MarkdownViewService.call(request.path)
    response.headers["Cache-Control"] = "public, max-age=300"
    render plain: markdown, content_type: "text/markdown; charset=utf-8"
  end
end
