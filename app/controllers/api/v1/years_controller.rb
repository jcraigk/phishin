module Api
  module V1
    class YearsController < ApiController
      
      caches_action :index, expires_in: CACHE_TTL
      caches_action :show, expires_in: CACHE_TTL

      def index
        respond_with_success(ERAS.values.flatten)
      end

      def show
        if params[:id].match /^(\d{4})-(\d+{4})$/
          shows = Show.avail.between_years($1, $2).includes(:venue).order('date asc')
        elsif params[:id].match /^(\d){4}$/
          shows = Show.avail.during_year(params[:id]).includes(:venue).order('date asc')
        else
          respond_with_failure('Invalid year or year range') and return
        end
        respond_with_success(shows)
      end

    end
  end
end