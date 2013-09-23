module Api
  module V1
    class ShowsController < ApiController

      def index
        respond_with_success get_data_for(Show)
      end

      def show
        if data = Show.where(id: params[:id]).first
          respond_with_success data
        else
          respond_with_failure 'Show not found'
        end
      end

    end
  end
end