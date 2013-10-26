module Api
  module V1
    class SongsController < ApiController

      def index
        respond_with_success get_data_for(Song)
      end

      def show
        show = Song.where(slug: params[:id]).first unless show = Song.where(id: params[:id]).first
        respond_with_success show
      end

    end
  end
end