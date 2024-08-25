require_relative "track_tag" # TODO: remove somehow

module Api::V2::Entities
  class Track < Grape::Entity
    expose :slug
    expose(:show_date) { |track| track.show.date.iso8601 }
    expose(:venue_name) { |track| track.show.venue_name }
    expose(:venue_location) { |track| track.show.venue.location }
    expose :title
    expose :position
    expose :duration
    expose :jam_starts_at_second
    expose :set
    expose :likes_count
    expose(:mp3_url) { |track| track.mp3_url }
    expose(:waveform_image_url) { |track| track.waveform_image_url }
    expose :track_tags, using: Api::V2::Entities::TrackTag, as: :tags
    expose(:song_titles) { |track| track.songs.map(&:title) }
    expose(:song_slugs) { |track| track.songs.map(&:slug) }
    expose :updated_at, format_with: :iso8601

    private

    format_with :iso8601 do |date|
      date.iso8601
    end
  end
end
