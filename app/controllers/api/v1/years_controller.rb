module Api
  module V1
    class YearsController < ApiController

      caches_action :index, cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL
      caches_action :show,  cache_path: Proc.new {|c| c.params }, expires_in: CACHE_TTL

      def index
        eras = ERAS.values.flatten

        # Include show_count for each era if include_show_counts present
        if params[:include_show_counts].present?
          eras = eras.each_with_object([]) do |era, list|
            shows = (era == '1983-1987' ? Show.avail.between_years('1983', '1987') : Show.avail.during_year(era))
            list << {
              date: era,
              show_count: shows.count
            }
          end
        end

        respond_with_success(eras)
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