module Api
  module V1
    class PlaylistsController < ApiController
      
      caches_action :show, cache_path: Proc.new { |c| c.params }, expires_in: CACHE_TTL

      def show
        playlist = Playlist.where(slug: params[:id]).first
        respond_with_success playlist
      end

    end
  end
end