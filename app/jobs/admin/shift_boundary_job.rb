# Moves the point where one track ends and the next begins, without losing a
# sample of what was on either side.
#
# The fix for a boundary an importer or a scan put slightly wrong: a song's
# first note stranded on the tail of the track above it, or the last chord of
# one song opening the next. Positive delta_s grows the first track and shrinks
# the second; negative does the reverse.
#
# Concat-then-recut, deliberately. Joining the pair is usually a stream copy,
# and the single cut that follows is the only lossy pass; trimming one side and
# re-encoding the other would be two. This is an archive, so the fewest
# decode/encode passes wins. The cut reuses TrackSplitService.filters so a
# boundary render is byte-for-byte the way a split renders.
#
# Metadata is untouched. Positions, titles, songs, likes, tags and playlist
# entries all describe the same two tracks they described before; only where
# the audio is cut changes.
#
# Gaps are not recomputed, matching split's behavior - the editor's gapsStale
# banner covers a published show.
class Admin::ShiftBoundaryJob
  include Sidekiq::Job

  # Both sides must survive the move with real audio on them. A boundary pushed
  # nearer than this to either far edge is a mis-typed delta, not an edit.
  MIN_PART_S = 1.0

  class NoNextTrackError < StandardError; end
  class MissingAudioError < StandardError; end
  class DeltaOutOfRangeError < StandardError; end

  def perform(track_id, admin_job_id, delta_s, apply)
    @first = Track.find(track_id)
    @delta_s = delta_s.to_f
    @apply = apply
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      find_second!
      ensure_audio!
      ensure_delta_in_stored_range!
      join
      ensure_delta_in_range!
      render_sides
      store_renders(admin_job)
      apply! if apply?
      admin_job.payload.merge!(payload)
      admin_job.save!
    end
  end

  private

  attr_reader :first, :second, :delta_s

  def apply? = @apply

  def show = first.show

  def find_second!
    @second = show.tracks.find_by(position: first.position + 1)
    return if @second
    raise NoNextTrackError,
          "#{show.date} #{first.title}: no track below position #{first.position}"
  end

  def ensure_audio!
    missing = [ first, second ].reject { it.mp3_audio.attached? }
    return if missing.empty?
    raise MissingAudioError,
          "no audio attached: #{missing.map { "#{show.date} #{it.title}" }.join(', ')}"
  end

  # The pair becomes one continuous file, exactly as it sounded end to end, and
  # the recut works from that. Always applied rather than dry run: a dry run
  # returns a Tempfile path whose finalizer deletes the file as soon as the
  # service is collected, and the recut needs the join to still be on disk. The
  # join writes nothing to the database either way, so an applied render is just
  # a durable one.
  def join
    @concat = TrackConcatService.call(tracks: [ first, second ])
    @joined_path = @concat[:output_path]
  end

  def first_duration_s = @concat[:source_durations].first

  def total_duration_s = @concat[:duration_s]

  # Where the boundary lands on the joined clock.
  def cut_s
    @cut_s ||= (first_duration_s + delta_s).round(2)
  end

  def allowed_range
    [ (MIN_PART_S - first_duration_s).round(1),
      (total_duration_s - MIN_PART_S - first_duration_s).round(1) ]
  end

  # Screened off the stored durations first, so an impossible delta costs no
  # ffmpeg time. The probed check below is the authority, but the two agree
  # except where a stored duration has drifted from its file.
  def ensure_delta_in_stored_range!
    low = (MIN_PART_S - first.duration.to_i / 1000.0).round(1)
    high = (second.duration.to_i / 1000.0 - MIN_PART_S).round(1)
    return if delta_s >= low && delta_s <= high
    raise DeltaOutOfRangeError, out_of_range_message(low, high)
  end

  def ensure_delta_in_range!
    return if cut_s >= MIN_PART_S && cut_s <= total_duration_s - MIN_PART_S
    raise DeltaOutOfRangeError, out_of_range_message(*allowed_range)
  end

  def out_of_range_message(low, high)
    "delta of #{delta_s.round(1)}s moves the boundary outside the audio; " \
      "allowed range is #{low}s to #{high}s"
  end

  def output_dir = Rails.root.join("tmp/track_boundaries")

  def side_paths
    @side_paths ||= [ 1, 2 ].map do |n|
      output_dir.join("#{show.date}_#{first.slug}_boundary#{n}.mp3")
    end
  end

  def bitrate
    @bitrate ||= begin
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error", "-show_entries", "format=bit_rate",
        "-of", "csv=p=0", @joined_path
      )
      raw = status.success? ? out.strip : ""
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def render_sides
    FileUtils.mkdir_p(output_dir)
    render(TrackSplitService.filters(start_s: 0.0, end_s: cut_s), side_paths[0])
    render(TrackSplitService.filters(start_s: cut_s), side_paths[1])
  end

  def render(filters, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @joined_path,
      "-af", filters.join(","), "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, out_path.to_s
    )
    raise TrackConcatService::Error, "ffmpeg failed for #{show.date}: #{err}" unless status.success?
  end

  # Both sides, so an admin auditions the end of the first track and the start
  # of the second before committing - hearing the seam from one side only is
  # what let a bad boundary through in the first place.
  def store_renders(admin_job)
    admin_job.payload["audio_paths"] = [
      AdminJobAudio.store(admin_job, side_paths[0].to_s, index: 0),
      AdminJobAudio.store(admin_job, side_paths[1].to_s, index: 1)
    ]
  end

  def apply!
    @backup_paths = [ back_up(first), back_up(second) ]
    attach(first, side_paths[0])
    attach(second, side_paths[1])
  end

  def back_up(record)
    FileUtils.mkdir_p(TrackAudioReplacer::BACKUP_DIR)
    path = TrackAudioReplacer::BACKUP_DIR.join(
      "#{record.show.date}_#{record.slug}_#{record.mp3_audio.blob.key}.mp3"
    )
    File.open(path, "wb") do |file|
      record.mp3_audio.blob.download { |chunk| file.write(chunk) }
    end
    path.to_s
  end

  # Through TrackAudioReplacer for the blob safety it already carries:
  # process_mp3_audio's ID3 rewrite REPLACES the attachment, and a replacement
  # purges the blob it displaced, so the blob handed in must be one nothing else
  # points at. The throwaway blob is purged once the replacer has copied out.
  def attach(record, path)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(path),
      filename: record.friendly_filename,
      content_type: "audio/mpeg"
    )
    TrackAudioReplacer.call(track: record.reload, blob:)
    blob.purge
  end

  def payload
    {
      "track_id" => first.id,
      "second_track_id" => second.id,
      "delta_s" => delta_s.round(2),
      "cut_s" => cut_s,
      "reencoded" => @concat[:reencoded],
      "total_duration_s" => total_duration_s,
      "source_durations" => @concat[:source_durations],
      "new_durations" => [ cut_s.round(1), (total_duration_s - cut_s).round(1) ],
      "backup_paths" => @backup_paths
    }.compact
  end
end
