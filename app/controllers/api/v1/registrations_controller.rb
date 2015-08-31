module Api
  module V1
    class RegistrationsController < DeviseController
      
      respond_to :json

      def create
        user = User.new(params[:user])
        if user.save
          render json:  { success: true, email: user.email }, status: 201
          return
        else
          warden.custom_failure!
          render json: user.errors, status: 422
        end
      end
    end
  end
end