class TrackAudioReplacer < ApplicationService
  option :track
  option :blob
  option :operation, default: -> { nil }
  option :admin_job, default: -> { nil }

  def call
    backup_path = back_up_existing_audio
    attach_new_audio
    track.update!(audio_status: "complete")
    track.reload.process_mp3_audio
    track.show.update_audio_status_from_tracks!
    orphan_timestamps if operation
    backup_path
  end

  private

  def orphan_timestamps
    TimestampShifter.call(
      track: track.reload, delta_s: nil, new_duration_s: nil,
      reason: "replace_audio"
    )
  end

  def back_up_existing_audio
    AudioBackup.store(track, operation: operation || "replace")
  end

  def attach_new_audio
    blob.open do |file|
      track.mp3_audio.attach(
        io: file,
        filename: track.friendly_filename,
        content_type: "audio/mpeg"
      )
    end
  end
end
