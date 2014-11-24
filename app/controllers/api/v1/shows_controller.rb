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

      def on_day_of_year
        if monthday = params[:day].match(/^(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})$/i)
          month = Date::MONTHNAMES.index(monthday[1].titleize)
        elsif monthday = params[:day].match(/^(\d{1,2})-(\d{1,2})$/i)
          month = monthday[1].to_i
        else
          respond_with_failure 'Invalid day'
        end
        day = Integer(monthday[2], 10)
        respond_with_success Show.avail.where('extract(month from date) = ?', month).where('extract(day from date) = ?', day).paginate(page: params[:page], per_page: params[:per_page])
      end
      
      def random
        respond_with_success Show.avail.random.includes(:venue, :tracks, :tags).first
      end

    end
  end
end