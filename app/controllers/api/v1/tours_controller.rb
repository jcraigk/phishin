module Api
  module V1
    class ToursController < ApiController
      
      caches_action :index, cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL
      caches_action :show,  cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL

      def index
        respond_with_success get_data_for(Tour)
      end

      def show
        tour = Tour.where(slug: params[:id]).includes(:shows).first unless tour = Tour.where(id: params[:id]).includes(:shows).first
        respond_with_success tour
      end

    end
  end
end