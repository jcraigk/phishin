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
      relation.where(audio_status: audio_status)
    when "complete_or_partial"
      relation.where(audio_status: %w[complete partial])
    else
      relation
    end
  end

  def apply_audio_status_filter_to_songs(songs, audio_status)
    case audio_status
    when "complete_or_partial"
      # Use a subquery to avoid DISTINCT issues with ORDER BY
      song_ids = Song.joins(:tracks)
                    .where(tracks: { audio_status: %w[complete partial] })
                    .select(:id)
                    .distinct
                    .pluck(:id)
      songs.where(id: song_ids)
    when "complete", "partial", "missing"
      song_ids = Song.joins(:tracks)
                    .where(tracks: { audio_status: audio_status })
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
                       .where(shows: { audio_status: audio_status })
                       .select(:id)
                       .distinct
                       .pluck(:id)
      venues.where(id: venue_ids)
    else
      venues
    end
  end
end
