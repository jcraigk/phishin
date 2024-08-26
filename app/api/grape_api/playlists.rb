class GrapeApi::Playlists < GrapeApi::Base
  resource :playlists do
    desc "Return a specific Playlist by slug"
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    get ":slug" do
      playlist = Playlist.includes(:tracks).find_by!(slug: params[:slug])
      present playlist, with: GrapeApi::Entities::Playlist
    end
  end
end
