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

  def editor_payload(show)
    show_summary(show).merge(
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
