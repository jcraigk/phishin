module Api
  module V1
    class VenuesController < ApiController
      
      caches_action :index, expires_in: CACHE_TTL
      caches_action :show, expires_in: CACHE_TTL

      def index
        respond_with_success get_data_for(Venue)
      end

      def show
        venue = Venue.where(slug: params[:id]).includes(:shows).first unless venue = Venue.where(id: params[:id]).includes(:shows).first
        respond_with_success venue
      end

    end
  end
end