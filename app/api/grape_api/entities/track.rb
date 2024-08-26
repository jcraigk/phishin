class GrapeApi::Entities::Track < GrapeApi::Entities::Base
  expose :slug

  with_options if: ->(_obj, opts) { opts[:show_details] } do
    expose(:show_date) { _1.show.date.iso8601 }
    expose(:venue_name) { _1.show.venue.name }
    expose(:venue_location) { _1.show.venue.location }
  end

  expose :title
  expose :position
  expose :duration
  expose :jam_starts_at_second
  expose :set
  expose :likes_count
  expose(:mp3_url) { _1.mp3_url }
  expose(:waveform_image_url) { _1.waveform_image_url }
  expose :track_tags, using: GrapeApi::Entities::TrackTag, as: :tags
  expose(:song_titles) { _1.songs.map(&:title) }
  expose(:song_slugs) { _1.songs.map(&:slug) }
  expose :updated_at, format_with: :iso8601
end
