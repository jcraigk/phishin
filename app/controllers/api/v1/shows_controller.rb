module Api
  module V1
    class ShowsController < ApiController
      
      caches_action :index, expires_in: CACHE_TTL
      caches_action :show, expires_in: CACHE_TTL
      # caches_action :on_date, expires_in: CACHE_TTL

      def index
        respond_with_success get_data_for(Show.avail)
      end

      def show
        if data = Show.where(id: params[:id]).includes(:venue, :tracks, :tags).first
          respond_with_success data
        elsif data = Show.where(date: params[:id]).includes(:venue, :tracks, :tags).first
          respond_with_success data
        else
          respond_with_failure 'Show not found'
        end
      end
      
      def on_date
        begin
          Date.parse(params[:date])
          respond_with_success Show.where(date: params[:date]).includes(:venue, :tracks, :tags).first
        rescue
          respond_with_failure 'Invalid date'
        end
      end
      
      def random
        respond_with_success Show.avail.random.includes(:venue, :tracks, :tags).first
      end

    end
  end
end