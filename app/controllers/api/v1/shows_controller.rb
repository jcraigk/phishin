module Api
  module V1
    class ShowsController < ApiController

      def index
        respond_with_success get_data_for(Show.avail)
      end

      def show
        if data = Show.where(id: params[:id]).includes(:venue, :tracks, :tags).first
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
        respond_with_success Show.random.includes(:venue, :tracks, :tags)
      end

    end
  end
end