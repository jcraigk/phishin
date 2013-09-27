module Api
  module V1
    class ToursController < ApiController

      def index
        respond_with_success get_data_for(Tour)
      end

      def show
        respond_with_success Tour.where(id: params[:id]).includes(:shows).first
      end

    end
  end
end