class GoogleSpreadsheetFetcher < ApplicationService
  attr_reader :spreadsheet_id, :range, :has_headers

  OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
  TOKEN_PATH = Rails.root.join("config/google_api.yml")

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

  def authorizer
    @authorizer ||=
      Google::Auth::UserAuthorizer.new \
        Google::Auth::ClientId.from_hash(json_creds),
        Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY,
        Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  end

  def json_creds
    JSON.parse(ENV.fetch("GOOGLE_API_CREDS_JSON", {}))
  end

  def credentials
    authorizer.get_credentials(user_id)
  end

  def user_id
    "default"
  end

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    return credentials if credentials
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = $stdin.gets
    authorizer.get_and_store_credentials_from_code(
      user_id:,
      code:,
      base_url: OOB_URI
    )
  end

  def has_headers
    @has_headers = opts[:headers].nil? ? true : opts[:headers]
  end
end
