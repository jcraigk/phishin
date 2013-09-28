module Api
  module V1
    class SearchApiController < ApiController
      
      include SearchLogic

      def show
        term = params[:id]
        if term.present?
          respond_with_success(params[:id])
        else
          resond_with_failure('Enter a term')
        end
      end

    end
  end
end