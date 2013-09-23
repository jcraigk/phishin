module Api
  module V1
    class VenuesController < ApiController

      def index
        respond_with_success get_data_for(Venue)
      end

      def show
        respond_with_success Venue.where(id: params[:id]).first
      end

    end
  end
end