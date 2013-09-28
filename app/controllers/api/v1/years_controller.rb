module Api
  module V1
    class YearsController < ApiController

      def index
        respond_with_success(ERAS.values.flatten)
      end

      def show
        if params[:id].match /^(\d{4})-(\d+{4})$/
          shows = Show.between_years($1, $2).includes(:venue).order('date asc')
        elsif params[:id].match /^(\d){4}$/
          shows = Show.during_year(params[:id]).includes(:venue).order('date asc')
        else
          respond_with_failure('Invalid year or year range') and return
        end
        respond_with_success(shows)
      end

    end
  end
end