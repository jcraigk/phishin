module TrackApiV1
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def as_json # rubocop:disable Metrics/MethodLength
      {
        id:,
        title:,
        position:,
        duration:,
        jam_starts_at_second:,
        set:,
        set_name:,
        likes_count:,
        slug:,
        mp3: mp3_url,
        waveform_image: waveform_image_url,
        song_ids: songs.map(&:id),
        updated_at: updated_at.iso8601
      }
    end

    def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      {
        id:,
        show_id: show.id,
        show_date: show.date.iso8601,
        venue_name: show.venue_name,
        venue_location: show.venue.location,
        title:,
        position:,
        duration:,
        jam_starts_at_second:,
        set:,
        set_name:,
        likes_count:,
        slug:,
        tags: track_tags_for_api,
        mp3: mp3_url,
        waveform_image: waveform_image_url,
        song_ids: songs.map(&:id),
        updated_at: updated_at.iso8601
      }
    end

    private

    def track_tags_for_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      tags = track_tags.map do |tt|
        {
          id: tt.tag.id,
          name: tt.tag.name,
          priority: tt.tag.priority,
          group: tt.tag.group,
          color: tt.tag.color,
          notes: tt.notes,
          transcript: tt.transcript,
          starts_at_second: tt.starts_at_second,
          ends_at_second: tt.ends_at_second
        }
      end
      tags.sort_by { |t| t[:priority] }
    end
  end
end
