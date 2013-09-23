module Api
  module V1
    class ShowsController < ApiController

      def index
        respond_with_success get_data_for(Show)
      end

      def show
        if data = Show.where(id: params[:id]).first
          respond_with_success data
        else
          respond_with_failure 'Show not found'
        end
      end
      
      def tracks
        data = get_data_for(Show.where(id: params[:id]).first.tracks).map do |track|
          {
            id: track.id,
            title: track.title,
            duration: track.duration,
            position: track.position,
            set: track.set
          }
        end
        respond_with_success data
      end

    end
  end
end