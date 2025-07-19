module ApiV2::Helpers::SharedHelpers
  extend Grape::API::Helpers

  # Use case-insensitive ASCII-based sorting on text columns
  def apply_sort(relation, secondary_col = nil, secondary_dir = :asc)
    attribute, direction = params[:sort].split(":")
    table_name = relation.table_name

    primary_column = relation.connection.schema_cache.columns(table_name).find { |col| col.name == attribute }
    primary_sort =
      if primary_column && %i[ string text ].include?(primary_column.type)
        "LOWER(#{table_name}.#{attribute}) COLLATE \"C\" #{direction}"
      else
        "#{table_name}.#{attribute} #{direction}"
      end
    relation = relation.order(Arel.sql(primary_sort))

    if secondary_col && attribute != secondary_col
      secondary_column = relation.connection.schema_cache.columns(table_name).find { |col| col.name == secondary_col }
      secondary_sort =
        if secondary_column && %i[ string text ].include?(secondary_column.type)
          "LOWER(#{table_name}.#{secondary_col}) COLLATE \"C\" #{secondary_dir}"
        else
          "#{table_name}.#{secondary_col} #{secondary_dir}"
        end

      relation = relation.order(Arel.sql(secondary_sort))
    end

    relation
  end

  def current_user
    return unless (token = headers["X-Auth-Token"])
    decoded_token = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )
    user_id = decoded_token[0]["sub"]
    User.find_by(id: user_id)
  rescue JWT::DecodeError
    nil
  end

  def authenticate!
    error!({ message: "Unauthorized" }, 401) unless current_user
  end

  def apply_audio_status_filter(relation, audio_status)
    case audio_status
    when "complete", "partial", "missing"
      relation.where(audio_status:)
    when "complete_or_partial"
      relation.with_audio
    else
      relation
    end
  end

  def apply_audio_status_filter_to_songs(songs, audio_status)
    case audio_status
    when "complete_or_partial"
      # Use a subquery to avoid DISTINCT issues with ORDER BY
      song_ids = Song.joins(:tracks)
                    .merge(Track.with_audio)
                    .select(:id)
                    .distinct
                    .pluck(:id)
      songs.where(id: song_ids)
    when "complete", "partial", "missing"
      song_ids = Song.joins(:tracks)
                    .where(tracks: { audio_status: })
                    .select(:id)
                    .distinct
                    .pluck(:id)
      songs.where(id: song_ids)
    else
      songs
    end
  end

  def apply_audio_status_filter_to_venues(venues, audio_status)
    case audio_status
    when "complete_or_partial"
      venues.where("shows_with_audio_count > 0")
    when "complete", "partial", "missing"
      venue_ids = Venue.joins(:shows)
                       .where(shows: { audio_status: })
                       .select(:id)
                       .distinct
                       .pluck(:id)
      venues.where(id: venue_ids)
    else
      venues
    end
  end

  def fetch_liked_ids(likable_type, items)
    return [] unless current_user && items

    if items.is_a?(Array) && items.first.is_a?(Integer)
      item_ids = items
    else
      item_ids = items.respond_to?(:map) ? items.map(&:id) : [ items.id ]
    end

    Like.where(
      likable_type:,
      likable_id: item_ids,
      user_id: current_user.id
    ).pluck(:likable_id)
  end

  def fetch_liked_show_ids(shows)
    return [] unless current_user && shows
    shows_array = shows.respond_to?(:any?) ? shows : [ shows ]
    return [] unless shows_array.any?
    fetch_liked_ids("Show", shows_array)
  end

  def fetch_liked_track_ids(tracks)
    return [] unless current_user && tracks
    tracks_array = tracks.respond_to?(:map) ? tracks : [ tracks ]
    fetch_liked_ids("Track", tracks_array)
  end

  def fetch_liked_playlist_ids(playlists)
    return [] unless current_user && playlists
    playlists_array = playlists.respond_to?(:map) ? playlists : [ playlists ]
    fetch_liked_ids("Playlist", playlists_array)
  end

  def cache_key_for_collection(resource_name)
    "api/v2/#{resource_name}?#{params.to_query}"
  end

  def cache_key_for_resource(resource_name, identifier)
    "api/v2/#{resource_name}/#{identifier}"
  end

  def cache_key_for_custom(path)
    "api/v2/#{path}"
  end

  def paginate_relation(relation)
    relation.paginate(page: params[:page], per_page: params[:per_page])
  end

  def pagination_metadata(paginated_collection)
    {
      total_pages: paginated_collection.total_pages,
      current_page: paginated_collection.current_page,
      total_entries: paginated_collection.total_entries
    }
  end

  def paginated_response(items_key, items, paginated_collection)
    {
      items_key => items,
      **pagination_metadata(paginated_collection)
    }
  end
end
