module Api
  module V1
    class ShowsController < ApiController
      
      caches_action :index, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL
      caches_action :show, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL
      caches_action :on_date, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL

      def index
        show = Show.avail
        show = show.tagged_with(params[:tag]) if params[:tag]
        respond_with_success get_data_for(show)
      end

      def show
        if params[:id] =~ /\d{4}-\d{2}-\d{2}/
          if data = Show.where(date: params[:id]).includes(:venue, :tracks, :tags).first
            respond_with_success data
          else
            respond_with_failure 'Show date not found'
          end
        else
          if data = Show.where(id: params[:id]).includes(:venue, :tracks, :tags).first
            respond_with_success data
          else
            respond_with_failure 'Show ID not found'
          end
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