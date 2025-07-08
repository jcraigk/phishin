class ApiV2::Entities::Song < ApiV2::Entities::Base
  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the song"
    }

  expose \
    :title,
    documentation: {
      type: "String",
      desc: "Title of the song"
    }

  expose \
    :alias,
    documentation: {
      type: "String",
      desc: "Alias or alternate title of the song, if any"
    }

  expose \
    :original,
    documentation: {
      type: "Boolean",
      desc: "Indicates if the song is an original composition"
    }

  expose \
    :artist,
    documentation: {
      type: "String",
      desc: "Artist associated with the song (if not original)"
    }

  expose \
    :tracks_count,
    documentation: {
      type: "Integer",
      desc: "Number of tracks associated with the song"
    }

  expose \
    :tracks_with_audio_count,
    documentation: {
      type: "Integer",
      desc: "Number of tracks with audio associated with the song"
    }

  expose \
    :created_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of initial creation"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of most recent update"
    }

  expose(
    :previous_performance_gap,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "Integer",
      desc: "Count of shows since the last performance of the song"
    }
  ) { _2[:songs_track].previous_performance_gap }

  expose(
    :previous_performance_slug,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "String",
      desc: "Slug of the last performance of the song"
    }
  ) { _2[:songs_track].previous_performance_slug }

  expose(
    :next_performance_gap,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "Integer",
      desc: "Count of shows until the next performance of the song"
    }
  ) { _2[:songs_track].next_performance_gap }

  expose(
    :next_performance_slug,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "String",
      desc: "Slug of the next performance of the song"
    }
  ) { _2[:songs_track].next_performance_slug }

  expose(
    :previous_performance_gap_with_audio,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "Integer",
      desc: "Count of shows since the last performance of the song where audio is present"
    }
  ) { _2[:songs_track].previous_performance_gap_with_audio }

  expose(
    :previous_performance_slug_with_audio,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "String",
      desc: "Slug of the last performance of the song where audio is present"
    }
  ) { _2[:songs_track].previous_performance_slug_with_audio }

  expose(
    :next_performance_gap_with_audio,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "Integer",
      desc: "Count of shows until the next performance of the song where audio is present"
    }
  ) { _2[:songs_track].next_performance_gap_with_audio }

  expose(
    :next_performance_slug_with_audio,
    if: ->(_, opts) { opts[:include_gaps] },
    documentation: {
      type: "String",
      desc: "Slug of the next performance of the song where audio is present"
    }
  ) { _2[:songs_track].next_performance_slug_with_audio }
end
