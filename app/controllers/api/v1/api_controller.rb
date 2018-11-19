# frozen_string_literal: true
class Api::V1::ApiController < ActionController::Base
  before_action :attempt_user_authorization!
  after_action :set_json_content_type

  protected

  def get_data_for(relation)
    configure_page_params
    relation.order(sort_str(relation))
            .paginate(page: params[:page], per_page: params[:per_page])
            .all
  end

  def respond_with_success(data, opts = {})
    total_entries = data.respond_to?(:total_entries) ? data.total_entries : 1
    total_pages = data.respond_to?(:total_pages) ? data.total_pages : 1
    page = data.respond_to?(:current_page) ? data.current_page : 1
    render json: {
      success: true,
      total_entries: total_entries,
      total_pages: total_pages,
      page: page,
      data: data_as_json(data, opts)
    }
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
    }
  end

  private

  def data_as_json(data, opts = {})
    if data.is_a?(Enumerable) && !data.is_a?(Hash)
      if opts[:serialize_method].present?
        data.map { |d| d.send(opts[:serialize_method]) }
      else
        data.first.respond_to?(:as_json_api) ? data.map(&:as_json_api) : data.map(&:as_json)
      end
    elsif opts[:serialize_method].present?
      data.send(opts[:serialize_method])
    else
      data.respond_to?(:as_json_api) ? data.as_json_api : data.as_json
    end
  end

  def set_json_content_type
    response.set_header('Content-Type', 'application/json')
  end

  def configure_page_params
    params[:page] ||= 1
    params[:per_page] ||= 20
  end

  def sort_str(relation)
    return nil unless params[:sort_attr] && params[:sort_dir]
    "#{sort_attr(relation)} #{sort_dir}"
  end

  def sort_attr(relation)
    params[:sort_attr].in?(relation.klass.new.attributes) ? params[:sort_attr] : 'id'
  end

  def sort_dir
    params[:sort_dir].in?(%w[asc desc]) ? params[:sort_dir] : 'desc'
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
