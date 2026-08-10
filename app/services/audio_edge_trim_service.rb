# Applies an approved edge trim to a track's audio: renders a trimmed MP3
# with ffmpeg, backs up the original file, replaces the attachment, and
# reprocesses duration, ID3 tags, and waveform. With dry_run: true it only
# renders the file for review. The filter chain is kept in lockstep with
# scripts/audio_edge_analysis.py by audio_edge_trim_service_parity_spec.rb.
class AudioEdgeTrimService < ApplicationService
  param :track
  option :trim_end
  option :trim_start, default: -> { 0.0 }
  option :fade_in, default: -> { 1.0 }
  option :fade_out, default: -> { 6.0 }
  option :min_cut, default: -> { MIN_CUT_S }
  option :dry_run, default: -> { false }

  MIN_CUT_S = 5.0
  OUTPUT_DIR = Rails.root.join("tmp/audio_trims")
  BACKUP_DIR = Rails.root.join("tmp/audio_trim_backups")

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

  def bitrate
    raw = probe(@original.path, "bit_rate")
    /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
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
    duration_s - (kept_end - trim_start)
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
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @original.path,
      "-af", filters.join(","), "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, output_path.to_s
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
  end

  def backup_original
    FileUtils.mkdir_p(BACKUP_DIR)
    @backup_path = BACKUP_DIR.join(
      "#{track.show.date}_#{track.slug}_#{track.mp3_audio.blob.key}.mp3"
    )
    FileUtils.cp(@original.path, @backup_path)
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

  def result
    {
      track_id: track.id,
      label:,
      output_path: output_path.to_s,
      backup_path: @backup_path&.to_s,
      old_duration_s: duration_s.round(1),
      kept_s: (kept_end - trim_start).round(1),
      cut_s: cut_s.round(1),
      applied: !dry_run
    }
  end
end
