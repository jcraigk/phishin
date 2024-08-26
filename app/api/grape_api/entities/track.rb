class GrapeApi::Entities::Track < GrapeApi::Entities::Base
  expose :slug

  with_options if: ->(_obj, opts) { opts[:show_details] } do
    expose(:show_date) { |obj| obj.show.date.iso8601 }
    expose(:venue_name) { |obj| obj.show.venue.name }
    expose(:venue_location) { |obj| obj.show.venue.location }
  end

  expose :title
  expose :position
  expose :duration
  expose :jam_starts_at_second
  expose :set
  expose :likes_count
  expose(:mp3_url) { |track| track.mp3_url }
  expose(:waveform_image_url) { |track| track.waveform_image_url }
  expose :track_tags, using: GrapeApi::Entities::TrackTag, as: :tags
  expose(:song_titles) { |track| track.songs.map(&:title) }
  expose(:song_slugs) { |track| track.songs.map(&:slug) }
  expose :updated_at, format_with: :iso8601
end
