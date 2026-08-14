class Admin::ImportShowJob
  include Sidekiq::Job

  TRACK_PROGRESS_CEILING = 90.0

  def perform(show_id, admin_job_id)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)

    @admin_job.run! do
      raise "Show #{@show.date} already has tracks" if @show.tracks.exists?

      match = ShowImporter::Matcher.call(date: @show.date.to_s, filenames: staged_blobs.keys.sort)
      assign_venue_and_tour(match)
      create_tracks(match.tracks)
      finalize
    end
  end

  private

  # Keyed by the unsanitized filename column, since ActiveStorage strips
  # characters like ">" out of Filename#to_s and the Matcher keys on segues.
  def staged_blobs
    @staged_blobs ||=
      @show.staged_audio_attachments
           .includes(:blob)
           .index_by { |attachment| Show.original_filename(attachment.blob) }
           .transform_values(&:blob)
  end

  def assign_venue_and_tour(match)
    payload = @admin_job.payload
    if match.venue
      @show.venue = match.venue
    else
      payload["unmatched_venue"] = {
        "name" => match.show_info.venue_name,
        "city" => match.show_info.venue_city
      }
    end
    match.tour ? @show.tour = match.tour : payload["unmatched_tour"] = true
    @show.save!
    @admin_job.update!(payload:)
  end

  def create_tracks(track_hashes)
    total = track_hashes.size
    track_hashes.each_with_index do |attrs, index|
      create_track(attrs)
      @admin_job.update!(
        progress: ((index + 1) * TRACK_PROGRESS_CEILING / total).round,
        message: "Imported #{attrs[:title]}"
      )
    end
  end

  def create_track(attrs)
    blob = staged_blobs[attrs[:filename]]
    track = Track.new(
      show: @show,
      position: attrs[:position],
      title: attrs[:title],
      set: attrs[:set].presence || "1",
      audio_status: blob ? "complete" : "missing"
    )
    track.songs << Song.find(attrs[:song_id]) if attrs[:song_id]
    track.save!

    return if blob.nil?
    attach_audio(track, blob)
    track.process_mp3_audio
  end

  # Give the track its own blob rather than sharing the staged one. Attaching
  # the staged blob directly would make process_mp3_audio's ID3 rewrite replace
  # that attachment, and replacement purges the blob it replaces: the staged
  # original would be destroyed out from under the show's staged_audio.
  def attach_audio(track, blob)
    blob.open do |file|
      track.mp3_audio.attach(
        io: file,
        filename: track.friendly_filename,
        content_type: "audio/mpeg"
      )
    end
  end

  # Release the staged originals once they have become track audio. detach
  # deletes only the join rows and leaves every blob in place; purge would
  # destroy blobs that a track may still be pointing at.
  def clear_staged_audio
    @show.staged_audio.detach
  end

  def finalize
    clear_staged_audio
    @show.reload
    @show.update_audio_status_from_tracks!
    @show.save_duration
    @admin_job.update!(message: "Import complete")
  end
end
