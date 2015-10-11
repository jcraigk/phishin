module Api
  module V1
    class VenuesController < ApiController
      
      caches_action :index, cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL
      caches_action :show,  cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL

      def index
        respond_with_success get_data_for(Venue)
      end

      def show
        venue = Venue.where(slug: params[:id]).first unless venue = Venue.where(id: params[:id]).first
        respond_with_success venue
      end

    end
  end
end