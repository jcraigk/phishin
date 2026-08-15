module ApiV2::Helpers::AdminHelper
  extend Grape::API::Helpers

  def authenticate_admin!
    error!({ message: "Unauthorized" }, 401) unless current_user
    error!({ message: "Forbidden" }, 403) unless current_user.admin?
  end

  def admin_show
    Show.find_by!(date: params[:date])
  end

  def staged_audio_payload(show)
    show.staged_audio_attachments.includes(:blob).map do |attachment|
      {
        attachment_id: attachment.id,
        filename: Show.original_filename(attachment.blob),
        byte_size: attachment.blob.byte_size
      }
    end
  end

  # Candidates are served straight from their blob rather than through a variant:
  # they are throwaway images the editor shows at review size, and building
  # variant records for art that is about to be discarded would leave orphaned
  # records behind.
  def cover_art_payload(show)
    {
      prompt: show.cover_art_prompt,
      hue: show.cover_art_hue,
      style: show.cover_art_style,
      parent_show_id: show.cover_art_parent_show_id,
      current_url: show.cover_art.attached? ? show.cover_art_urls[:large] : nil,
      album_cover_url: show.album_cover.attached? ? show.album_cover_url : nil,
      candidates: show.cover_art_candidates_attachments.includes(:blob).map do |attachment|
        {
          blob_key: attachment.blob.key,
          url: "#{App.base_url}/blob/#{attachment.blob.key}.png"
        }
      end
    }
  end

  def editor_payload(show)
    show_summary(show).merge(
      cover_art: cover_art_payload(show),
      taper_notes: show.taper_notes,
      admin_notes: show.admin_notes,
      venue_id: show.venue_id,
      tour_id: show.tour_id,
      exclude_from_stats: show.performance_gap_value.zero?,
      performance_gap_value: show.performance_gap_value,
      matches_pnet: show.matches_pnet,
      staged_audio: staged_audio_payload(show),
      tracks: show.tracks.order(:position).map { |track| track_payload(track) }
    )
  end

  def track_payload(track)
    {
      id: track.id,
      position: track.position,
      set: track.set,
      title: track.title,
      slug: track.slug,
      duration: track.duration,
      audio_status: track.audio_status,
      jam_starts_at_second: track.jam_starts_at_second,
      exclude_from_stats: track.exclude_from_stats,
      songs: track.songs.map { |song| { id: song.id, title: song.title } },
      mp3_url: track.mp3_url,
      waveform_url: track.waveform_image_url
    }
  end

  def show_summary(show)
    {
      id: show.id,
      date: show.date.iso8601,
      venue_name: show.venue_name,
      published: show.published,
      audio_status: show.audio_status,
      tracks_count: show.tracks.count,
      duration: show.duration
    }
  end
end
