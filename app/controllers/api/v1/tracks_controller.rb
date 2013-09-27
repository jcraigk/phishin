module Api
  module V1
    class TracksController < ApiController
      
      def index
        respond_with_success get_data_for(Track)
      end

      def show
        respond_with_success Track.where(id: params[:id]).first
      end
      
      def songs
        respond_with_success Track.where(id: params[:id]).first.songs
      end

    end
  end
end