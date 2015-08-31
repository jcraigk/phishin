module Api
  module V1
    class PasswordsController < DeviseController

      def create
        if user = User.where(email: params[:user][:email]).first
          #todo this sends api route, need to override that with non-API route
          user.send_reset_password_instructions

          render json: { success: true }
        else
          render json: { success: false, message: 'Email address not found' }
        end
      end
    end
  end
end