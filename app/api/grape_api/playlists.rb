class GrapeApi::Playlists < GrapeApi::Base
  resource :playlists do
    desc "Return a specific Playlist by slug" do
      detail "Fetches a Playlist by its slug, including all associated tracks"
      success GrapeApi::Entities::Playlist
      failure [ [ 404, "Not Found", GrapeApi::Entities::ApiResponse ] ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    get ":slug" do
      playlist = Playlist.includes(:tracks).find_by!(slug: params[:slug])
      present playlist, with: GrapeApi::Entities::Playlist
    end

    desc "Create a new Playlist" do
      detail "Creates a new Playlist for the authenticated user"
      success GrapeApi::Entities::Playlist
      failure [ [ 422, "Unprocessable Entity", GrapeApi::Entities::ApiResponse ] ]
    end
    params do
      requires :name, type: String, desc: "Name of the playlist"
      requires :slug, type: String, desc: "Slug of the playlist"
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
      present playlist, with: GrapeApi::Entities::Playlist
    end

    desc "Update an existing Playlist" do
      detail "Updates the name of an existing Playlist owned by the authenticated user"
      success GrapeApi::Entities::Playlist
      failure [
        [ 404, "Not Found", GrapeApi::Entities::ApiResponse ],
        [ 422, "Unprocessable Entity", GrapeApi::Entities::ApiResponse ]
      ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
      requires :name, type: String, desc: "Updated name of the playlist"
    end
    put ":slug" do
      authenticate!
      playlist = Playlist.find_by!(user: current_user, slug: params[:slug])
      playlist.update!(name: params[:name])
      present playlist, with: GrapeApi::Entities::Playlist
    end

    desc "Delete a Playlist" do
      detail "Deletes a Playlist owned by the authenticated user"
      success GrapeApi::Entities::ApiResponse
      failure [
        [ 404, "Not Found", GrapeApi::Entities::ApiResponse ],
        [ 403, "Forbidden", GrapeApi::Entities::ApiResponse ]
      ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    delete ":slug" do
      authenticate!
      current_user.playlists.find_by!(slug: params[:slug]).destroy!
      present({ message: "Playlist deleted successfully" }, with: GrapeApi::Entities::ApiResponse)
    end
  end
end
