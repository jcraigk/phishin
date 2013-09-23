module Api
  module V1
    class SongsController < ApiController

      def index
        respond_with_success get_data_for(Song)
      end

      def show
        respond_with_success Song.where(id: params[:id]).first
      end
      
      def tracks
        data = get_data_for(Song.where(id: params[:id]).first.tracks).map do |track|
          {
            id: track.id,
            title: track.title,
            duration: track.duration,
            position: track.position,
            set: track.set,
            show_id: track.show_id
          }
        end
        respond_with_success data
      end

    end
  end
end