module Api
  module V1
    class TracksController < ApiController
      
      caches_action :index, expires_in: CACHE_TTL
      caches_action :show, expires_in: CACHE_TTL
      
      def index
        respond_with_success get_data_for(Track)
      end

      def show
        respond_with_success Track.where(id: params[:id]).includes(:tags).first
      end

    end
  end
end