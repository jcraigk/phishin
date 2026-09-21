module ApiV2::Helpers::AdminHelper
  extend Grape::API::Helpers

  def authenticate_admin!
    error!({ message: "Unauthorized" }, 401) unless current_user
    error!({ message: "Forbidden" }, 403) unless current_user.admin?
  end

  def admin_show
    Show.find_by!(date: params[:date])
  end

  def ensure_draft_without_tracks!(show)
    error!({ message: "Show #{show.date} is already published" }, 422) if show.published?
    error!({ message: "Show #{show.date} already has tracks" }, 422) if show.tracks.exists?
  end

  def find_signed_blob(signed_id)
    ActiveStorage::Blob.find_signed!(signed_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    error!({ message: "Unknown upload: #{signed_id}" }, 422)
  end

  def enqueue_job(kind, job_class, show:, track: nil, args: [])
    job = AdminJob.create!(kind:, show:, track:)
    job_class.perform_async(track&.id || show.id, job.id, *args)
    status 201
    { job_id: job.id }
  end

  def cover_art_payload(show)
    {
      prompt: show.cover_art_prompt,
      model: show.cover_art_model,
      image_models: CoverArtImageService::MODELS,
      default_image_model: CoverArtImageService.default_model,
      parent_show_id: show.cover_art_parent_show_id,
      parent_show_date: Show.find_by(id: show.cover_art_parent_show_id)&.date&.to_s,
      child_dates: Show.where(cover_art_parent_show_id: show.id).order(:date).pluck(:date).map(&:to_s),
      current_url: show.cover_art.attached? ? show.cover_art_urls[:large] : nil,
      current_blob_key: show.cover_art.attached? ? show.cover_art.blob.key : nil,
      album_cover_url: show.album_cover.attached? ? show.album_cover_url : nil,
      candidates: show.cover_art_candidates_attachments.includes(:blob).map do |attachment|
        {
          blob_key: attachment.blob.key,
          url: "#{App.base_url}/blob/#{attachment.blob.key}.png",
          cost: attachment.blob.metadata["cost"],
          model: attachment.blob.metadata["model"],
          prompt: attachment.blob.metadata["prompt"],
          edits: attachment.blob.metadata["edits"] || []
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
      staging: staging_payload(show),
      show_tags: show_tags_payload(show),
      tracks: show.tracks.order(:position).map { |track| track_payload(track) }
    )
  end

  def staging_payload(show)
    return nil unless show.staging?
    sources = show.staged_sources.order(:position)
    {
      source_url: show.staging_source_url,
      commit_job_id: active_job_id(show, "commit_staging"),
      total_s: sources.sum(&:duration_s).to_f,
      peaks_url: File.exist?(Admin::StagingDir.new(show).peaks) ? "/api/v2/admin/shows/#{show.date}/staging/peaks" : nil,
      peaks_rate: Admin::StagingPeaks::RATE,
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
      tracks: staged_tracks_payload(show)
    }
  end

  def active_job_id(show, kind)
    AdminJob.active.where(show:, kind:).order(:id).last&.id
  end

  def staged_tracks_payload(show)
    tracks = show.staged_tracks.ordered.to_a
    songs = Song.where(id: tracks.flat_map(&:song_ids)).index_by(&:id)
    tracks.map do |track|
      staged_track_payload(track, track.song_ids.filter_map { songs[it] })
    end
  end

  def staged_track_payload(track, songs)
    {
      id: track.id,
      position: track.position,
      set: track.set,
      title: track.title,
      songs: songs.map { { id: it.id, title: it.title } },
      undo_combine: track.combines.last&.dig("following", "title"),
      start_s: track.start_s.to_f,
      end_s: track.end_s.to_f,
      original_start_s: track.original_start_s&.to_f,
      original_end_s: track.original_end_s&.to_f,
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
        transcript: track_tag.transcript
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
      venue_slug: show.venue&.slug,
      published: show.published,
      audio_status: show.audio_status,
      staged: show.staging?,
      ingest_job_id: active_job_id(show, "ingest"),
      tracks_count: show.tracks.count,
      duration: show.duration,
      cover_art_url: show.cover_art_urls[:small],
      tags: show.tags.map(&:name).sort
    }
  end
end
