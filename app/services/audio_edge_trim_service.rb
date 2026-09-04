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
  option :edge_previews, default: -> { false }
  option :tail_pad, default: -> { PREVIEW_PAD_S }
  option :admin_job, default: -> { nil }

  MIN_CUT_S = 5.0
  PREVIEW_PAD_S = 2.0
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
    if dry_run && edge_previews
      render_edge_previews
    else
      render_trimmed
    end

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

  def head_path
    @head_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_trim_head.mp3")
  end

  def tail_path
    @tail_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_trim_tail.mp3")
  end

  def head_len = [ fade_in + PREVIEW_PAD_S, kept_s ].min

  def tail_len = [ fade_out + tail_pad, kept_s ].min

  def render_edge_previews
    FileUtils.mkdir_p(OUTPUT_DIR)
    render_preview(filters + TrackSplitService.filters(start_s: 0.0, end_s: head_len), head_path)
    render_preview(
      filters + TrackSplitService.filters(start_s: [ kept_s - tail_len, 0.0 ].max),
      tail_path
    )
  end

  def render_preview(chain, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @original.path,
      "-af", chain.join(","), "-b:a", "192k", out_path.to_s
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
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

  def shift_timestamps
    @shift = TimestampShifter.call(
      track: track.reload, delta_s: -trim_start, new_duration_s: kept_s,
      reason: "trim"
    )
  end

  def kept_s = kept_end - trim_start

  def result
    base = {
      track_id: track.id,
      label:,
      old_duration_s: duration_s.round(1),
      kept_s: kept_s.round(1),
      cut_s: cut_s.round(1),
      applied: !dry_run
    }
    if dry_run && edge_previews
      base.merge(preview_paths: [ head_path.to_s, tail_path.to_s ])
    else
      base.merge(output_path: output_path.to_s, backup_path: @backup_path&.to_s)
    end
  end
end
