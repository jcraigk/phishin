module Api
  module V1
    class SongsController < ApiController

      def index
        respond_with_success get_data_for(Song)
      end

      def show
        respond_with_success Song.where(id: params[:id]).first
      end

    end
  end
end