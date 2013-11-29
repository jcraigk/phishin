module Api
  module V1
    class SongsController < ApiController
      
      caches_action :index, expires_in: CACHE_TTL
      caches_action :show, expires_in: CACHE_TTL

      def index
        respond_with_success get_data_for(Song.relevant)
      end

      def show
        show = Song.where(slug: params[:id]).first unless show = Song.where(id: params[:id]).first
        respond_with_success show
      end

    end
  end
end