module Api
  module V1
    class TracksController < ApiController

      def show
        respond_with_success Track.where(id: params[:id]).first
      end
      
      def songs
        data = get_data_for(Track.where(id: params[:id]).first.songs).map do |song|
          {
            id: song.id,
            title: song.title
          }
        end
        respond_with_success data
      end

    end
  end
end