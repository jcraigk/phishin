class Server
  WIDGETS_DIR = Rails.root.join("public", "mcp-widgets")
  WIDGET_ASSET_HOST_PLACEHOLDER = "{{WIDGET_ASSET_HOST}}"

  WIDGET_CONFIG = {
    domain: "phishin",
    csp: {
      connect_domains: [
        "https://phish.in"
      ],
      resource_domains: [
        "https://phish.in"
      ]
    }
  }.freeze

  VALID_CLIENTS = %i[default openai].freeze

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
      resources = client == :openai ? widget_resources : []

      server = MCP::Server.new(
        name: "phishin",
        version: "1.0.0",
        tools:,
        resources:,
        configuration: MCP::Configuration.new(protocol_version: "2025-03-26")
      )

      if client == :openai
        server.resources_read_handler do |params|
          read_widget(params[:uri])
        end
      end

      server
    end
  end

  def self.widget_resources
    return [] unless Dir.exist?(WIDGETS_DIR)

    Dir.glob(WIDGETS_DIR.join("*.html").to_s).map do |file_path|
      filename = File.basename(file_path)
      widget_name = File.basename(filename, ".html").tr("-_", " ").split.map(&:capitalize).join(" ")

      MCP::Resource.new(
        uri: widget_uri_for_file(filename),
        name: "#{widget_name} Widget",
        description: "Interactive #{widget_name.downcase} display",
        mime_type: "text/html+skybridge"
      )
    end
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

  def self.read_widget(uri)
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

    [ {
      uri:,
      mimeType: "text/html+skybridge",
      text:,
      _meta: {
        "openai/widgetDomain" => WIDGET_CONFIG[:domain],
        "openai/widgetCSP" => widget_csp
      }
    } ]
  end

  def self.compile_widget_if_stale(widget_name)
    WidgetCompiler.compile_if_stale(widget_name)
  rescue StandardError => e
    Rails.logger.error "[WidgetCompiler] Failed to compile #{widget_name}: #{e.message}"
  end
end
