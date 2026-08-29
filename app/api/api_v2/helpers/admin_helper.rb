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
      current_blob_key: show.cover_art.attached? ? show.cover_art.blob.key : nil,
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
      staging: staging_payload(show),
      show_tags: show_tags_payload(show),
      tracks: show.tracks.order(:position).map { |track| track_payload(track) }
    )
  end

  # Nil rather than an empty structure when nothing is staged, so the editor
  # can branch on presence alone.
  def staging_payload(show)
    return nil unless show.staging?
    sources = show.staged_sources.order(:position)
    {
      source_url: show.staging_source_url,
      total_s: sources.sum(&:duration_s).to_f,
      sources: sources.map do |source|
        {
          id: source.id,
          position: source.position,
          filename: source.filename,
          format: source.format,
          offset_s: source.offset_s.to_f,
          duration_s: source.duration_s.to_f,
          audio_url: "/api/v2/admin/shows/#{show.date}/staging/sources/#{source.id}/audio"
        }
      end,
      tracks: show.staged_tracks.ordered.includes(:song).map { staged_track_payload(it) }
    }
  end

  def staged_track_payload(track)
    {
      id: track.id,
      position: track.position,
      set: track.set,
      title: track.title,
      song: track.song && { id: track.song.id, title: track.song.title },
      start_s: track.start_s.to_f,
      end_s: track.end_s.to_f,
      fade_in_s: track.fade_in_s.to_f,
      fade_out_s: track.fade_out_s.to_f
    }
  end

  def show_tags_payload(show)
    show.show_tags.includes(:tag).map do |show_tag|
      {
        id: show_tag.id,
        tag_id: show_tag.tag_id,
        tag_name: show_tag.tag.name,
        notes: show_tag.notes
      }
    end
  end

  def track_tags_payload(track)
    track.track_tags.includes(:tag).map do |track_tag|
      {
        id: track_tag.id,
        tag_id: track_tag.tag_id,
        tag_name: track_tag.tag.name,
        notes: track_tag.notes,
        starts_at_second: track_tag.starts_at_second,
        ends_at_second: track_tag.ends_at_second,
        transcript: track_tag.transcript,
        orphaned_at: track_tag.orphaned_at,
        orphan_reason: track_tag.orphan_reason
      }
    end
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
      track_tags: track_tags_payload(track),
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
      duration: show.duration,
      cover_art_url: show.cover_art_urls[:small],
      tags: show.tags.map(&:name).sort
    }
  end
end
