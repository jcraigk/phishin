module Api
  module V1
    class UsersController < ApiController

      def show
        if user = User.where(username: params[:username]).first
          respond_with_success user.username
        else
          respond_with_failure 'Username not found'
        end
      end

    end
  end
end