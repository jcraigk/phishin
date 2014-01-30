module Api
  module V1
    class TracksController < ApiController
      
      caches_action :index, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL
      caches_action :show, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL
      
      def index
        respond_with_success get_data_for(Track)
      end

      def show
        respond_with_success Track.where(id: params[:id]).includes(:tags).first
      end

    end
  end
end