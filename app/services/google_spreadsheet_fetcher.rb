# frozen_string_literal: true
class GoogleSpreadsheetFetcher
  attr_reader :spreadsheet_id, :range

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  CREDENTIALS_PATH = "#{Rails.root}/tmp/credentials.json"
  TOKEN_PATH = "#{Rails.root}/tmp/token.yml"

  def initialize(spreadsheet_id, range)
    @spreadsheet_id = spreadsheet_id
    @range = range
  end

  def call
    authorize_client
    fetch_data
  end

  private

  def authorize_client
    service.client_options.application_name = 'Phish.in Tag.in Project'
    service.authorization = authorize
  end

  def fetch_data
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
      Google::Auth::UserAuthorizer.new(
        client_id,
        Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY,
        token_store
      )
  end

  def token_store
    @token_store ||= Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  end

  def client_id
    @client_id ||= Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  end

  def user_id
    'default'
  end

  def credentials
    @credentials ||= authorizer.get_credentials(user_id)
  end

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts 'Open the following URL in the browser and enter the ' \
           "resulting code after authorization:\n" + url
      code = STDIN.gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end
end
