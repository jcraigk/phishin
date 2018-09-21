# frozen_string_literal: true
class Api::V1::ApiController < ActionController::Base
  before_action :attempt_user_authorization!
  before_action :cors_preflight_check
  after_action :cors_set_access_control_headers

  protected

  def get_data_for(model)
    configure_page_params
    configure_sort_params(model)
    model.order("#{params[:sort_attr]} #{params[:sort_dir]}")
         .paginate(page: params[:page], per_page: params[:per_page])
         .all
  end

  def respond_with_success(data)
    total_entries = data.respond_to?(:total_entries) ? data.total_entries : 1
    total_pages = data.respond_to?(:total_pages) ? data.total_pages : 1
    page = data.respond_to?(:current_page) ? data.current_page : 1
    render json: {
      success: true,
      total_entries: total_entries,
      total_pages: total_pages,
      page: page,
      data: data_as_json(data)
    }, content_type: 'application/json'
  end

  def respond_with_success_simple(message = nil)
    response = { success: true }
    response[:message] = message if message.present?
    render json: response
  end

  def respond_with_failure(message = nil)
    render json: {
      success: false,
      message: message
    }, content_type: 'application/json'
  end

  def configure_page_params
    params[:page]     ||= 1
    params[:per_page] ||= 20
  end

  def configure_sort_params(obj, default_attr = nil)
    %w[asc desc].include?(params[:sort_attr]) ? params[:sort_attr] : 'desc'
    attrs = obj.new.attributes
    default_attr ||= attrs.first
    attrs.key?(params[:sort_attr]) ? params[:sort_attr] : default_attr
  end

  def data_as_json(data)
    if data.is_a?(Enumerable)
      data.first.respond_to?(:as_json_api) ? data.map(&:as_json_api) : data.map(&:as_json)
    else
      data.respond_to?(:as_json_api) ? data.as_json_api : data.as_json
    end
  end

  private

  def cors_preflight_check
    return unless request.method == :options
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = '*'
    headers['Access-Control-Max-Age'] = '1728000'
    render text: '', content_type: 'text/plain'
  end

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization, Range'
    headers['Access-Control-Max-Age'] = '1728000'
  end

  def attempt_user_authorization!
    return unless params[:user].present? &&
                  params[:user][:email].present? &&
                  params[:user][:auth_token].present?
    authenticate_user_from_token!
  end

  # https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
  def authenticate_user_from_token!
    return if current_user

    user_email = params[:user][:email].presence
    user = user_email && User.find_by_email(user_email)
    return sign_in('user', user) if user && secure_compare

    render json: { success: false, message: 'Invalid email or auth_token' }
  end

  def secure_compare
    Devise.secure_compare(
      user.authentication_token,
      params[:user][:auth_token]
    )
  end
end
