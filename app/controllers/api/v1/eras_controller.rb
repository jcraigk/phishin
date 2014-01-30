module Api
  module V1
    class ErasController < ApiController
      
      caches_action :index, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL
      caches_action :show, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL

      def index
        respond_with_success(ERAS)
      end

      def show
        if [1, 2, 3].include? params[:id].to_i
          respond_with_success(ERAS["#{params[:id]}.0"])
        else
          respond_with_failure('Invalid era; enter as single integer') and return
        end
      end

    end
  end
end