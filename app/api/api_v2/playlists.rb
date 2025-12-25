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
      requires :starts_at_second,
               type: Array[Integer],
               desc: \
                "Array of starting positions of " \
                "associated track selections in track_ids array"
      requires :ends_at_second,
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
               values: SORT_COLS.map { |opt| [ "#{opt}:asc", "#{opt}:desc" ] }.flatten
      optional :filter,
               type: String,
               desc: "Filter by user ownership or user likes. Requires authentication.",
               values: %w[all mine liked]
    end
    get do
      result = page_of_playlists
      liked_playlist_ids = fetch_liked_playlist_ids(result[:playlists])
      liked_track_ids = fetch_liked_track_ids(result[:playlists])
      {
        playlists: ApiV2::Entities::Playlist.represent(
          result[:playlists],
          liked_playlist_ids:,
          liked_track_ids:,
          exclude_tracks: true
        ),
        total_pages: result[:total_pages],
        current_page: result[:current_page],
        total_entries: result[:total_entries]
      }
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
      begin
        playlist = Playlist.create!(
          user: current_user,
          name: params[:name],
          slug: params[:slug],
          playlist_tracks_attributes: track_attrs_from_params
        )
        present playlist, with: ApiV2::Entities::Playlist
      rescue ActiveRecord::RecordInvalid => e
        error!({ message: e.record.errors.full_messages.join(", ") }, 422)
      end
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
      begin
        update_playlist_data(playlist)
        present playlist, with: ApiV2::Entities::Playlist
      rescue ActiveRecord::RecordInvalid => e
        error!({ message: e.record.errors.full_messages.join(", ") }, 422)
      end
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
      playlists =
        if params[:filter].in?(%w[liked mine]) && current_user
          fetch_playlists
        else
          Rails.cache.fetch(cache_key_for_collection("playlists")) { fetch_playlists }
        end

      paginated_response(:playlists, playlists, playlists)
    end

    def fetch_playlists
      Playlist.includes(:user)
              .then { |p| apply_filter(p) }
              .then { |p| apply_sort(p, :name, :asc) }
              .then { |p| paginate_relation(p) }
    end

    def fetch_liked_track_ids(playlists)
      return [] unless current_user
      track_ids = playlists.flat_map { |playlist| playlist.tracks.pluck(:id) }
      fetch_liked_ids("Track", track_ids)
    end

    def apply_filter(playlists)
      if !params[:filter].in?(%w[mine liked])
        playlists = playlists.published
      elsif current_user && params[:filter] == "liked"
        liked_playlist_ids = current_user.likes.where(likable_type: "Playlist").pluck(:likable_id)
        playlists = playlists.where(id: liked_playlist_ids)
      elsif current_user && params[:filter] == "mine"
        playlists = playlists.where(user: current_user)
      end

      playlists
    end

    def track_attrs_from_params
      params[:track_ids].compact.map.with_index do |track_id, idx|
        starts_at, ends_at = sanitize_track_times(
          starts_at: params[:starts_at_second][idx],
          ends_at: params[:ends_at_second][idx],
          track_duration: Track.find(track_id).duration / 1000
        )

        {
          track_id:,
          position: idx + 1,
          starts_at_second: starts_at,
          ends_at_second: ends_at
        }
      end
    end

    def sanitize_track_times(starts_at:, ends_at:, track_duration:)
      starts_at = starts_at.to_i
      ends_at = ends_at.to_i

      # starts_at must be positive and less than track duration
      # If ends_at is also specified, starts_at must be less than ends_at
      if starts_at <= 0 || starts_at >= track_duration || (ends_at > 0 && starts_at >= ends_at)
        starts_at = nil
      end

      # ends_at must be positive and not exceed track duration
      if ends_at <= 0 || ends_at > track_duration
        ends_at = nil
      end

      [ starts_at, ends_at ]
    end

    def update_playlist_data(playlist)
      ActiveRecord::Base.transaction do
        playlist.playlist_tracks.destroy_all
        playlist.update! \
          name: params[:name],
          description: params[:description],
          slug: params[:slug],
          published: params[:published],
          playlist_tracks_attributes: track_attrs_from_params
      end
    end
  end
end
