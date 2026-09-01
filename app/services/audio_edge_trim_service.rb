# Applies an approved edge trim to a track's audio: renders a trimmed MP3
# with ffmpeg, backs up the original file, replaces the attachment, and
# reprocesses duration, ID3 tags, and waveform. With dry_run: true it only
# renders the file for review. The filter chain is kept in lockstep with
# scripts/audio_edge_analysis.py by audio_edge_trim_service_parity_spec.rb.
class AudioEdgeTrimService < ApplicationService
  include LameEncoding

  param :track
  option :trim_end
  option :trim_start, default: -> { 0.0 }
  option :fade_in, default: -> { 1.0 }
  option :fade_out, default: -> { 6.0 }
  option :min_cut, default: -> { MIN_CUT_S }
  option :dry_run, default: -> { false }
  # Unused by the render itself; kept so callers can hand the job through
  # without caring whether anything downstream still wants it.
  option :admin_job, default: -> { nil }

  MIN_CUT_S = 5.0
  OUTPUT_DIR = Rails.root.join("tmp/audio_trims")

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class TrimTooSmallError < Error; end

  # Mirror of trim_filters() in scripts/audio_edge_analysis.py. Both must build
  # the same chain for the same inputs or a lead-scan preview stops matching
  # what actually gets applied; spec/services/audio_edge_trim_service_parity_spec.rb
  # fails if they drift.
  def self.filters(trim_start:, trim_end:, fade_in:, fade_out:)
    kept = trim_end - trim_start
    list = [ format("atrim=start=%.2f:end=%.2f", trim_start, trim_end), "asetpts=PTS-STARTPTS" ]
    list << format("afade=t=in:st=0:d=%.2f", fade_in) if trim_start.positive? && fade_in.positive?
    if fade_out.positive?
      fade = [ fade_out, kept ].min
      list << format("afade=t=out:st=%.2f:d=%.2f", kept - fade, fade)
    end
    list
  end

  def call
    raise MissingAudioError, "#{label} has no audio attached" if track.missing_audio?

    download_original
    ensure_meaningful_cut
    render_trimmed

    unless dry_run
      backup_original
      replace_audio
      shift_timestamps
    end

    result
  ensure
    @original&.close!
  end

  private

  def label
    "#{track.show.date} #{track.title}"
  end

  def download_original
    @original = Tempfile.new([ "track_#{track.id}_original", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| @original.write(chunk) }
    @original.flush
  end

  def duration_s
    @duration_s ||= probe(@original.path, "duration").to_f
  end


  def probe(path, entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=#{entry}",
      "-of", "csv=p=0", path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip
  end

  def kept_end
    @kept_end ||= [ trim_end, duration_s ].min
  end

  def cut_s
    duration_s - kept_s
  end

  def ensure_meaningful_cut
    return if cut_s >= min_cut
    raise TrimTooSmallError,
          "#{label}: only #{cut_s.round(1)}s would be cut (minimum #{min_cut}s)"
  end

  def filters
    self.class.filters(
      trim_start:, trim_end: kept_end, fade_in:,
      fade_out: kept_end < duration_s - 0.1 ? fade_out : 0.0
    )
  end

  def output_path
    @output_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_trimmed.mp3")
  end

  def render_trimmed
    FileUtils.mkdir_p(OUTPUT_DIR)
    render_via_lame(output_path, [ "-i", @original.path, "-af", filters.join(",") ])
  end

  def backup_original
    @backup_path = AudioBackup.store_file(@original.path, track:, operation: "trim")
  end

  def replace_audio
    track.mp3_audio.attach(
      io: File.open(output_path),
      filename: track.friendly_filename,
      content_type: "audio/mpeg"
    )
    track.reload
    track.process_mp3_audio
  end

  # Every timestamp on this track is measured from the head of the audio, and
  # the head is exactly what trim_start cut off, so the whole track's clock moves
  # back by that much. A tail-only trim has a delta of zero and still matters:
  # kept_s is shorter than the track was, so a window past the new end no longer
  # describes anything and orphans. The fades do not enter into it - they change
  # what the first and last seconds sound like, not where any second is.
  def shift_timestamps
    @shift = TimestampShifter.call(
      track: track.reload, delta_s: -trim_start, new_duration_s: kept_s,
      reason: "trim"
    )
  end

  def kept_s = kept_end - trim_start


  def result
    {
      track_id: track.id,
      label:,
      output_path: output_path.to_s,
      backup_path: @backup_path&.to_s,
      old_duration_s: duration_s.round(1),
      kept_s: kept_s.round(1),
      cut_s: cut_s.round(1),
      applied: !dry_run
    }
  end
end
