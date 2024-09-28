class ApiV2::Playlists < ApiV2::Base
  SORT_COLS = %w[name likes_count tracks_count duration updated_at]

  helpers do
    params :playlist_params do
      requires :name,
               type: String,
               desc: "Name of the playlist"
      requires :slug,
               type: String,
               desc: "Slug of the playlist"
      requires :description,
               type: String,
               desc: "Description of the playlist"
      requires :published,
               type: Boolean,
               desc: \
                "Published flag (true to make browseable/searchable " \
                "by public users, false to make private)"
      requires :track_ids,
               type: Array[Integer],
               desc: "Array of track IDs that make up the playlist"
      requires :starts_at_seconds,
               type: Array[Integer],
               desc: \
                "Array of starting positions of " \
                "associated track selections in track_ids array"
      requires :ends_at_seconds,
               type: Array[Integer],
               desc:
                "Array of ending positions of " \
                "associated track selections in track_ids array"
    end
  end

  resource :playlists do
    desc "Fetch a list of playlists" do
      detail "Fetch a filtered, sorted, paginated list of playlists"
      success ApiV2::Entities::Playlist
      failure [
        [ 400, "Bad Request", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      use :pagination
      optional :sort,
               type: String,
               desc: "Sort by attribute and direction (e.g., 'likes_count:desc')",
               default: "likes_count:desc",
               values: SORT_COLS.map { |opt| ["#{opt}:asc", "#{opt}:desc"] }.flatten
      optional :filter,
               type: String,
               desc: "Filter by user ownership or user likes. Requires authentication.",
               values: %w[all mine liked]
    end
    get do
      result = page_of_playlists
      liked_playlist_ids = fetch_liked_playlist_ids(result[:playlists])
      liked_track_ids = fetch_liked_track_ids(result[:playlists])
      present \
        playlists: ApiV2::Entities::Playlist.represent(
          result[:playlists],
          liked_playlist_ids:,
          liked_track_ids:,
          exclude_tracks: true
        ),
        total_pages: result[:total_pages],
        current_page: result[:current_page],
        total_entries: result[:total_entries]
    end

    desc "Fetch a playlist by slug" do
      detail "Fetch a playlist by its slug, including all associated tracks"
      success ApiV2::Entities::Playlist
      failure [ [ 404, "Not Found", ApiV2::Entities::ApiResponse ] ]
    end
    params do
      requires :slug, type: String, desc: "Slug of the playlist"
    end
    get ":slug" do
      playlist = Playlist.includes(:tracks).find_by!(slug: params[:slug])
      present \
        playlist,
        with: ApiV2::Entities::Playlist,
        liked_by_user: current_user&.likes&.exists?(likable: playlist) || false
    end

    desc "Create a new playlist" do
      detail "Creates a new playlist for the authenticated user"
      success ApiV2::Entities::Playlist
      failure [ [ 422, "Unprocessable Entity", ApiV2::Entities::ApiResponse ] ]
    end
    params { use :playlist_params }
    post do
      authenticate!
      if Playlist.where(user: current_user).count >= App.max_playlists_per_user
        error!(
          { message: "Each user is limited to #{App.max_playlists_per_user} playlists" },
          403
        )
      end
      playlist = Playlist.create! \
        user: current_user,
        name: params[:name],
        slug: params[:slug],
        playlist_tracks_attributes: track_attributes_from_params
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
      use :playlist_params
      requires :id,
               type: Integer,
               desc: "ID of the playlist"
    end
    put ":id" do
      authenticate!
      playlist = current_user.playlists.find(params[:id])
      update_playlist_data(playlist)
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
      requires :id, type: Integer, desc: "ID of the playlist"
    end
    delete ":id" do
      authenticate!
      current_user.playlists.find(params[:id]).destroy!
      status 204
    end
  end

  helpers do
    def page_of_playlists
      Rails.cache.fetch("api/v2/playlists?#{params.to_query}") do
        playlists = Playlist.includes(:user)
                            .then { |p| apply_filter(p) }
                            .then { |p| apply_sort(p, :name, :asc) }
                            .paginate(page: params[:page], per_page: params[:per_page])

        {
          playlists: playlists,
          total_pages: playlists.total_pages,
          current_page: playlists.current_page,
          total_entries: playlists.total_entries
        }
      end
    end

    def fetch_liked_playlist_ids(playlists)
      return [] unless current_user
      Like.where(
        likable_type: "Playlist",
        likable_id: playlists.map(&:id),
        user_id: current_user.id
      ).pluck(:likable_id)
    end

    def fetch_liked_track_ids(playlists)
      return [] unless current_user
      track_ids = playlists.flat_map { |playlist| playlist.tracks.pluck(:id) }
      Like.where(
        likable_type: "Track",
        likable_id: track_ids,
        user_id: current_user.id
      ).pluck(:likable_id)
    end

    def apply_filter(playlists)
      if !params[:filter].in?(%w[mine liked])
        # playlists = playlists.published # TODO: re-enable when published flag is added
      elsif current_user && params[:filter] == "liked"
        liked_playlist_ids = current_user.likes.where(likable_type: "Playlist").pluck(:likable_id)
        playlists = playlists.where(id: liked_playlist_ids)
      elsif current_user && params[:filter] == "mine"
        playlists = playlists.where(user: current_user)
      end

      playlists
    end

    def track_attributes_from_params
      params[:track_ids].map.with_index do |track_id, idx|
        {
          track_id:,
          position: idx + 1,
          starts_at_second: params[:starts_at_seconds][idx],
          ends_at_second: params[:ends_at_seconds][idx]
        }
      end
    end

    def update_playlist_data(playlist)
      ActiveRecord::Base.transaction do
        playlist.playlist_tracks.destroy_all
        playlist.update! \
          name: params[:name],
          description: params[:description],
          slug: params[:slug],
          published: params[:published],
          playlist_tracks_attributes: track_attributes_from_params
      end
    end
  end
end
