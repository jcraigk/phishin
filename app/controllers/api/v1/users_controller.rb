module Api
  module V1
    class UsersController < ApiController

      before_filter :get_user

      #todo show more user info?
      def show
        respond_with_success(@user.username)
      end
      
      def playlists
        playlists = Playlist.where(user_id: @user.id).all
        respond_with_success playlists.map(&:as_json_api_basic)
      end

      private

      def get_user
        unless @user = User.where(username: params[:username]).first
          respond_with_failure('Username not found')
        end
      end

    end
  end
end