class ApiV2::Playlists < ApiV2::Base
  resource :playlists do
    desc "Return a specific playlist by slug" do
      detail "Return a playlist by its slug, including all associated tracks"
      success ApiV2::Entities::Playlist
      failure [ [ 404, "Not Found", ApiV2::Entities::ApiResponse ] ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    get ":slug" do
      playlist = Playlist.includes(:tracks).find_by!(slug: params[:slug])
      present playlist, with: ApiV2::Entities::Playlist
    end

    desc "Create a new playlist" do
      detail "Creates a new playlist for the authenticated user"
      success ApiV2::Entities::Playlist
      failure [ [ 422, "Unprocessable Entity", ApiV2::Entities::ApiResponse ] ]
    end
    params do
      requires :name, type: String, desc: "Name of the playlist"
      requires :slug, type: String, desc: "Slug of the playlist"
      optional :track_ids,
               type: Array[Integer],
               desc: "Array of track IDs to associate with the playlist"
    end
    post do
      authenticate!
      if Playlist.where(user: current_user).count >= App.max_playlists_per_user
        error!(
          { message: "Each user is limited to #{App.max_playlists_per_user} playlists" },
          403
        )
      end

      playlist = Playlist.create!(user: current_user, name: params[:name], slug: params[:slug])
      update_playlist_tracks(playlist, params[:track_ids])

      present playlist, with: ApiV2::Entities::Playlist
    end

    desc "Update an existing playlist" do
      detail "Updates an existing playlist for an authenticated user"
      success ApiV2::Entities::Playlist
      failure [
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ],
        [ 422, "Unprocessable Entity", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
      requires :name, type: String, desc: "Updated name of the playlist"
      optional :track_ids,
               type: Array[Integer],
               desc: "Array of track IDs to update the playlist with"
    end
    put ":slug" do
      authenticate!
      playlist = Playlist.find_by!(user: current_user, slug: params[:slug])
      playlist.update!(name: params[:name])
      update_playlist_tracks(playlist, params[:track_ids])

      present playlist, with: ApiV2::Entities::Playlist
    end

    desc "Delete a playlist" do
      detail "Deletes a playlist owned by the authenticated user"
      success [ { status: 204 } ]
      failure [
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ],
        [ 403, "Forbidden", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    delete ":slug" do
      authenticate!
      current_user.playlists.find_by!(slug: params[:slug]).destroy!
      status 204
    end
  end

  helpers do
    def update_playlist_tracks(playlist, track_ids)
      return unless track_ids

      playlist.playlist_tracks.destroy_all
      track_ids.each_with_index do |track_id, index|
        playlist.playlist_tracks.create!(track_id:, position: index + 1)
      end
    end
  end
end
