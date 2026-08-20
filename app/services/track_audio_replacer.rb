# Swaps a track's audio for the bytes of another blob, keeping the file it
# displaces on disk first.
#
# The per-track unit of the replace flow: Admin::ReplaceAudioJob calls it once
# for the track an admin uploaded over, and a bulk upsert calls it once per
# track it matched. Callers hand it a blob rather than a signed id so a bulk
# caller can pass blobs it built itself.
class TrackAudioReplacer < ApplicationService
  BACKUP_DIR = Rails.root.join("tmp/audio_replacements")

  option :track
  option :blob
  # Nil means "I am somebody else's primitive": shift the audio, touch no
  # timestamp, write no record. Boundary shift and combine both attach through
  # here with audio whose offsets they have already worked out themselves, and
  # orphaning on their behalf would throw away a mapping they got right. The two
  # replace jobs pass their own operation name and get the orphaning they need.
  option :operation, default: -> { nil }
  option :admin_job, default: -> { nil }

  def call
    backup_path = back_up_existing_audio
    attach_new_audio
    track.update!(audio_status: "complete")
    track.reload.process_mp3_audio
    track.show.update_audio_status_from_tracks!
    record_replacement(backup_path) if operation
    backup_path
  end

  private

  # A wholesale replacement admits NO delta. The new file is a different
  # recording, or the same one from a different source, and nothing in it says
  # where the old file's 66-second mark went - it may not exist at all. So every
  # timestamp on the track is orphaned for review with its numbers intact, which
  # is the one honest answer: a guess here would move a jam chart entry to a
  # moment nobody checked.
  def record_replacement(backup_path)
    shift = TimestampShifter.call(
      track: track.reload, delta_s: nil, new_duration_s: nil,
      reason: "replace_audio"
    )
    TrackEdit.record!(
      track:, operation:, admin_job:, shift:,
      duration_before_s: @duration_before_s,
      duration_after_s: track.reload.duration.to_i / 1000.0,
      delta_s: nil,
      backup_path:
    )
  end

  # Returns nil for a track that had no audio: that is the fill case a bulk
  # upsert hits on most tracks, not an error.
  def back_up_existing_audio
    # Read before anything is attached: it is the only point where the row still
    # reports the length of the audio being displaced.
    @duration_before_s = track.duration.to_i / 1000.0
    return nil unless track.mp3_audio.attached?

    FileUtils.mkdir_p(BACKUP_DIR)
    path = BACKUP_DIR.join(backup_filename)
    File.open(path, "wb") do |file|
      track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    end
    path.to_s
  end

  def backup_filename
    "#{track.show.date}_#{track.slug}_#{track.mp3_audio.blob.key}.mp3"
  end

  # Copy the bytes into a blob of the track's own rather than attaching the
  # source blob. process_mp3_audio's ID3 rewrite replaces the attachment, and
  # replacement purges the blob it replaces: attaching the source directly would
  # destroy an upload that the job's caller, or another track in a bulk run, may
  # still be pointing at.
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
