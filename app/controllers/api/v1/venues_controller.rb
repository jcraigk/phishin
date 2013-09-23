module Api
  module V1
    class VenuesController < ApiController

      def index
        respond_with_success get_data_for(Venue)
      end

      def show
        respond_with_success Venue.where(id: params[:id]).first
      end
      
      def shows
        data = get_data_for(Venue.where(id: params[:id]).first.shows).map do |show|
          {
            id: show.id,
            date: show.date
          }
        end
        respond_with_success data
      end

    end
  end
end