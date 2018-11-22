# frozen_string_literal: true
class Api::V1::ApiController < ActionController::Base
  after_action :set_json_content_type

  rescue_from ActiveRecord::RecordNotFound, with: :respond_with_404

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

  def respond_with_404
    render json: {
      success: false,
      message: 'Record not found'
    }, status: 404
  end

  private

  def data_as_json(data, opts = {})
    if data.is_a?(Enumerable) && !data.is_a?(Hash)
      serialize_collection(data, opts)
    elsif opts[:serialize_method].present?
      data.send(opts[:serialize_method])
    else
      data.respond_to?(:as_json_api) ? data.as_json_api : data.as_json
    end
  end

  def serialize_collection(data, opts)
    if opts[:serialize_method].present?
      data.map { |d| d.send(opts[:serialize_method]) }
    else
      data.first.respond_to?(:as_json_api) ? data.map(&:as_json_api) : data.map(&:as_json)
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
end
