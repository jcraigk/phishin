module Api
  module V1
    class ApiController < ActionController::Base
      
      # http_basic_authenticate_with name: "dhh", password: "secret"
  
      respond_to :json
  
      protected
      
      def get_data_for(model)
        configure_page_params
        configure_sort_params(model)
        model.order("#{params[:sort_attr]} #{params[:sort_dir]}").paginate(page: params[:page], per_page: params[:per_page]).all
      end
      
      def respond_with_success(data)
        total_entries = data.respond_to?(:total_entries) ? data.total_entries : 1
        total_pages = data.respond_to?(:total_pages) ? data.total_pages : 1
        page = data.respond_to?(:current_page) ? data.current_page : 1
        respond_with success: true, total_entries: total_entries, total_pages: total_pages, page: page, data: data_as_json(data)
      end
      
      def respond_with_failure(message=nil)
        respond_with success: false, message: message
      end
      
      def configure_page_params
        params[:page] ||= 1
        params[:per_page] ||= 20
      end
  
      def configure_sort_params(obj, default_attr=nil)
        %w(asc desc).include?(params[:sort_attr]) ? params[:sort_attr] : 'desc'
        attributes = obj.new.attributes
        default_attr ||= attributes.first
        attributes.keys.include?(params[:sort_attr]) ? params[:sort_attr] : default_attr
      end
      
      def data_as_json(data)
        data.respond_to?(:as_json_api) ? data.try(:as_json_api) : data.try(:as_json)
      end
  
    end
  end
end