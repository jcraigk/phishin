require "webrick"
require "securerandom"
require "uri"
require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"

class GoogleSpreadsheetFetcher < ApplicationService
  attr_reader :spreadsheet_id, :range, :has_headers

  REDIRECT_PORT = 8000
  REDIRECT_HOST = "localhost"

  param :spreadsheet_id
  param :range
  option :opts, optional: true, default: -> { {} }

  def call
    service.authorization = authorize
    fetch_data
  end

  private

  def fetch_data
    return response unless has_headers
    column_headers = response.shift
    response.map do |row|
      {}.tap do |hash|
        column_headers.each_with_index do |title, idx|
          hash[title] = row[idx]
        end
      end
    end
  end

  def service
    @service ||= Google::Apis::SheetsV4::SheetsService.new
  end

  def response
    @response ||= service.get_spreadsheet_values(spreadsheet_id, range).values.to_a
  end

  def credentials
    @credentials ||= JSON.parse(ENV.fetch("GOOGLE_SPREADSHEET_CREDS", "{}"))
  end

  def authorize
    if credentials["refresh_token"].present?
      return Google::Auth::UserRefreshCredentials.new(
        client_id: credentials["client_id"],
        client_secret: credentials["client_secret"],
        refresh_token: credentials["refresh_token"],
        scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
      )
    end

    # Fall back to interactive flow only in development
    if Rails.env.development?
      # Generate a state token to prevent request forgery
      state = SecureRandom.hex(24)
      code = nil

      # Create a redirect URI for the local server
      redirect_uri = "http://#{REDIRECT_HOST}:#{REDIRECT_PORT}"

      # Create authorizer with local redirect
      authorizer = Google::Auth::UserAuthorizer.new(
        Google::Auth::ClientId.new(
          credentials["client_id"],
          credentials["client_secret"]
        ),
        Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY,
        MemoryTokenStore.new
      )

      # Get the authorization URL
      auth_url = authorizer.get_authorization_url(
        base_url: redirect_uri,
        state:
      )

      puts "Opening browser for authorization..."
      puts "If your browser doesn't open automatically, visit this URL:"
      puts auth_url

      # Try to open the browser automatically
      if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
        system("start", auth_url)
      elsif RbConfig::CONFIG["host_os"] =~ /darwin/
        system("open", auth_url)
      elsif RbConfig::CONFIG["host_os"] =~ /linux|bsd/
        system("xdg-open", auth_url)
      end

      # Start a temporary web server to handle the OAuth callback
      server = WEBrick::HTTPServer.new(
        Port: REDIRECT_PORT,
        BindAddress: REDIRECT_HOST,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: []
      )

      # Define a handler for the OAuth callback
      server.mount_proc "/" do |req, res|
        # Check if this is the OAuth callback
        if req.query["code"] && req.query["state"] == state
          code = req.query["code"]
          res.body = "Authorization successful! You can close this window now."
          server.shutdown
        else
          res.body = "Invalid request"
        end
      end

      # Run the server in a separate thread
      trap("INT") { server.shutdown }
      thread = Thread.new { server.start }

      # Wait for the authorization code
      puts "Waiting for authorization..."
      thread.join

      # Exchange the authorization code for credentials
      if code
        credentials = authorizer.get_credentials_from_code(
          user_id: "default",
          code:,
          base_url: redirect_uri
        )

        # Output complete credentials to be stored in environment
        new_creds = credentials.merge({
          "refresh_token" => credentials.refresh_token
        })

        puts "\nSet this as your GOOGLE_SPREADSHEET_CREDS environment variable:"
        puts JSON.generate(new_creds)

        credentials
      else
        raise "Authorization failed"
      end
    else
      raise "No valid credentials found and not in development environment"
    end
  end

  def has_headers
    @has_headers = opts[:headers].nil? ? true : opts[:headers]
  end

  # Simple in-memory token store implementation
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
