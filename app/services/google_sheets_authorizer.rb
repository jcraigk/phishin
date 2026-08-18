require "webrick"
require "securerandom"
require "uri"
require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"

class GoogleSheetsAuthorizer < ApplicationService
  REDIRECT_PORT = 8000
  REDIRECT_HOST = "localhost"

  option :scope, default: -> { Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY }
  option :force_interactive, default: -> { false }

  def call
    return refresh_credentials if use_refresh_token?
    raise "No valid credentials found and not in development environment" unless Rails.env.development?
    interactive_credentials
  end

  private

  def use_refresh_token?
    !force_interactive && credentials["refresh_token"].present?
  end

  def credentials
    @credentials ||= JSON.parse(ENV.fetch("GOOGLE_SPREADSHEET_CREDS", "{}"))
  end

  def refresh_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: credentials["client_id"],
      client_secret: credentials["client_secret"],
      refresh_token: credentials["refresh_token"],
      scope:
    )
  end

  def interactive_credentials
    state = SecureRandom.hex(24)
    code = fetch_auth_code(state)
    raise "Authorization failed" if code.blank?

    new_credentials = authorizer.get_credentials_from_code(
      user_id: "default",
      code:,
      base_url: redirect_uri
    )

    print_credentials(new_credentials)
    new_credentials
  end

  def redirect_uri
    @redirect_uri ||= "http://#{REDIRECT_HOST}:#{REDIRECT_PORT}"
  end

  def authorizer
    @authorizer ||= Google::Auth::UserAuthorizer.new(
      Google::Auth::ClientId.new(credentials["client_id"], credentials["client_secret"]),
      scope,
      MemoryTokenStore.new
    )
  end

  def fetch_auth_code(state)
    auth_url = authorizer.get_authorization_url(base_url: redirect_uri, state:)

    puts "Opening browser for authorization..."
    puts "If your browser doesn't open automatically, visit this URL:"
    puts auth_url
    open_browser(auth_url)

    run_callback_server(state)
  end

  def open_browser(auth_url)
    case RbConfig::CONFIG["host_os"]
    when /mswin|mingw|cygwin/ then system("start", auth_url)
    when /darwin/ then system("open", auth_url)
    when /linux|bsd/ then system("xdg-open", auth_url)
    end
  end

  def run_callback_server(state)
    code = nil
    server = WEBrick::HTTPServer.new(
      Port: REDIRECT_PORT,
      BindAddress: REDIRECT_HOST,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )

    server.mount_proc "/" do |req, res|
      if req.query["code"] && req.query["state"] == state
        code = req.query["code"]
        res.body = "Authorization successful! You can close this window now."
        server.shutdown
      else
        res.body = "Invalid request"
      end
    end

    trap("INT") { server.shutdown }
    puts "Waiting for authorization..."
    Thread.new { server.start }.join

    code
  end

  def print_credentials(new_credentials)
    payload = credentials.merge("refresh_token" => new_credentials.refresh_token)
    puts "\nSet this as your GOOGLE_SPREADSHEET_CREDS environment variable:"
    puts JSON.generate(payload)
  end

  class MemoryTokenStore < Google::Auth::TokenStore
    def initialize
      @tokens = {}
    end

    def load(id)
      @tokens[id]
    end

    def store(id, token)
      @tokens[id] = token
    end

    def delete(id)
      @tokens.delete(id)
    end
  end
end
