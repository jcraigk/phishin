module Api
  module V1
    class ApiController < ActionController::Base
      before_filter :attempt_user_authorization!
      before_filter :cors_preflight_check
      after_filter  :cors_set_access_control_headers

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

      def configure_sort_params(obj, default_attr=nil)
        %w(asc desc).include?(params[:sort_attr]) ? params[:sort_attr] : 'desc'
        attributes = obj.new.attributes
        default_attr ||= attributes.first
        attributes.keys.include?(params[:sort_attr]) ? params[:sort_attr] : default_attr
      end

      def data_as_json(data)
        data.respond_to?(:as_json_api) ? data.try(:as_json_api) : data.try(:as_json)
      end

      private

      def cors_preflight_check
        if request.method == :options
          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
          headers['Access-Control-Allow-Headers'] = '*'
          headers['Access-Control-Max-Age'] = '1728000'
          render text: '', content_type: 'text/plain'
        end
      end

      def cors_set_access_control_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
        headers['Access-Control-Request-Method'] = '*'
        headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization, Range'
        headers['Access-Control-Max-Age'] = '1728000'
      end

      def attempt_user_authorization!
        authenticate_user_from_token! if params[:user].present? and params[:user][:email].present? and params[:user][:auth_token].present?
      end

      # https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
      def authenticate_user_from_token!
        unless current_user
          user_email  = params[:user][:email].presence
          user        = user_email && User.find_by_email(user_email)

          if user && Devise.secure_compare(user.authentication_token, params[:user][:auth_token])
            sign_in('user', user)
          else
            render json: { success: false, message: 'Invalid email or auth_token' }
          end
        end
      end

    end
  end
end