class Server
  WIDGETS_DIR = Rails.root.join("public", "mcp-widgets")
  WIDGET_ASSET_HOST_PLACEHOLDER = "{{WIDGET_ASSET_HOST}}"
  APP_NAME_PLACEHOLDER = "{{MCP_APP_NAME}}"
  LOGO_FULL_PLACEHOLDER = "{{MCP_LOGO_FULL}}"
  LOGO_SQUARE_PLACEHOLDER = "{{MCP_LOGO_SQUARE}}"

  CLIENT_BRANDING = {
    openai: {
      app_name: -> { App.app_name_mcp },
      logo_full: "logo-full-mcp.png",
      logo_square: "logo-square-mcp.png"
    },
    default: {
      app_name: -> { App.app_name },
      logo_full: "logo-full.png",
      logo_square: "logo-square.png"
    }
  }.freeze

  WIDGET_CONFIG = {
    domain: "phishin",
    csp: {
      connect_domains: [
        "https://phish.in"
      ],
      resource_domains: [
        "https://phish.in",
        "blob:"
      ]
    }
  }.freeze

  VALID_CLIENTS = %i[default openai anthropic].freeze
  WIDGET_CLIENTS = %i[openai anthropic].freeze

  class << self
    def for_client(client)
      client_sym = client.to_sym
      raise ArgumentError, "Invalid client: #{client}" unless VALID_CLIENTS.include?(client_sym)

      @instances ||= {}
      @instances[client_sym] ||= build_server(client_sym)
    end

    def reset!
      @instances = {}
    end

    private

    def build_server(client)
      tools = ToolBuilder.build_tools(client:)
      resources = WIDGET_CLIENTS.include?(client) ? widget_resources(client:) : []

      server = MCP::Server.new(
        name: "phishin",
        version: "1.0.0",
        tools:,
        resources:,
        configuration: MCP::Configuration.new(protocol_version: "2025-03-26")
      )

      if WIDGET_CLIENTS.include?(client)
        server.resources_read_handler do |params|
          read_widget(params[:uri], client:)
        end
      end

      server
    end
  end

  def self.widget_resources(client:)
    return [] unless Dir.exist?(WIDGETS_DIR)

    Dir.glob(WIDGETS_DIR.join("*.html").to_s).map do |file_path|
      filename = File.basename(file_path)
      widget_name = File.basename(filename, ".html").tr("-_", " ").split.map(&:capitalize).join(" ")

      MCP::Resource.new(
        uri: widget_uri_for_file(filename),
        name: "#{widget_name} Widget",
        description: "Interactive #{widget_name.downcase} display",
        mime_type: widget_mime_type(client:)
      )
    end
  end

  def self.widget_mime_type(client:)
    client == :openai ? "text/html+skybridge" : "text/html;profile=mcp-app"
  end

  def self.widget_uri(tool_name)
    filename = "#{tool_name}.html"
    widget_uri_for_file(filename)
  end

  def self.widget_uri_for_file(filename)
    file_path = WIDGETS_DIR.join(filename)
    version = file_path.exist? ? Digest::SHA256.file(file_path).hexdigest[0, 8] : "0"
    "ui://widget/#{version}/#{filename}"
  end

  def self.widget_asset_host
    ENV.fetch("MCP_WIDGET_ASSET_HOST", App.base_url).to_s
  end

  def self.widget_csp
    csp = WIDGET_CONFIG[:csp].deep_dup
    hosts =
      [
        widget_asset_host,
        (App.production_base_url if defined?(App)),
        (App.base_url if defined?(App)),
        (App.content_base_url if defined?(App))
      ].compact.uniq.select { |h| h.start_with?("http://", "https://") }

    csp[:resource_domains] |= hosts
    csp[:connect_domains] |= hosts

    csp
  end

  def self.read_widget(uri, client:)
    return [] unless uri.to_s.start_with?("ui://widget/")

    uri_without_scheme = uri.to_s.sub("ui://widget/", "")
    parts = uri_without_scheme.split("/")
    filename = parts.last&.split("?")&.first
    return [] if filename.blank?

    widget_name = File.basename(filename, ".html")
    compile_widget_if_stale(widget_name) if Rails.env.development?

    file_path = WIDGETS_DIR.join(filename)
    return [] unless File.exist?(file_path)

    text = File.read(file_path)
    asset_host = widget_asset_host
    text = text.gsub(WIDGET_ASSET_HOST_PLACEHOLDER, asset_host) if asset_host.present?

    branding = CLIENT_BRANDING[client] || CLIENT_BRANDING[:default]
    text = text.gsub(APP_NAME_PLACEHOLDER, branding[:app_name].call)
    text = text.gsub(LOGO_FULL_PLACEHOLDER, branding[:logo_full])
    text = text.gsub(LOGO_SQUARE_PLACEHOLDER, branding[:logo_square])

    [ {
      uri:,
      mimeType: widget_mime_type(client:),
      text:,
      _meta: widget_meta(client:)
    } ]
  end

  def self.widget_meta(client:)
    case client
    when :openai
      {
        "openai/widgetDomain" => WIDGET_CONFIG[:domain],
        "openai/widgetCSP" => widget_csp
      }
    else
      {
        ui: {
          domain: anthropic_widget_domain,
          csp: widget_csp_mcp
        }
      }
    end
  end

  def self.anthropic_widget_domain
    endpoint_url = "#{App.base_url}/mcp/anthropic"
    hash = Digest::SHA256.hexdigest(endpoint_url)[0, 32]
    "#{hash}.claudemcpcontent.com"
  end

  def self.widget_csp_mcp
    csp = widget_csp
    {
      resourceDomains: csp[:resource_domains],
      connectDomains: csp[:connect_domains]
    }
  end

  def self.compile_widget_if_stale(widget_name)
    WidgetCompiler.compile_if_stale(widget_name)
  rescue StandardError => e
    Rails.logger.error "[WidgetCompiler] Failed to compile #{widget_name}: #{e.message}"
  end
end
