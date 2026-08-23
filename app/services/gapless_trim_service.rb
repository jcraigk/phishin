# Removes encoder padding from the edges of a track's mp3.
#
# An mp3 exported without a LAME header carries its encoder delay and end
# padding as ordinary samples, because nothing in the file tells a decoder how
# much to strip. On its own that is inaudible; between two tracks it is a
# dropout of tens of milliseconds. See lib/tasks/gapless_scan.rake for how the
# cuts are measured.
#
# The cuts are supplied rather than derived: the scan decides what is safe to
# remove, this only applies it. Both are optional, so a track can have its head
# trimmed, its tail, or both.
class GaplessTrimService < ApplicationService
  param :track
  option :head_cut, default: -> { 0.0 }
  option :tail_cut, default: -> { 0.0 }
  option :dry_run, default: -> { false }

  # Encoder padding runs to tens of milliseconds. Anything beyond this is not
  # padding, and a caller asking for it has measured something else.
  MAX_CUT_S = 0.25
  # Below this the re-encode costs more than the cut is worth.
  MIN_CUT_S = 0.004
  OUTPUT_DIR = Rails.root.join("tmp/gapless_trims")
  BACKUP_DIR = Rails.root.join("tmp/gapless_trim_backups")

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class NothingToTrimError < Error; end
  class TrimTooLargeError < Error; end

  def call
    raise MissingAudioError, "#{label} has no audio attached" if track.missing_audio?
    validate!
    download_original
    validate_against_duration!
    render_trimmed

    return result if dry_run

    backup_original
    replace_audio
    result
  ensure
    @original&.close!
  end

  private

  def label
    "#{track.show.date} #{track.title}"
  end

  def validate!
    if head_cut.negative? || tail_cut.negative?
      raise TrimTooLargeError, "#{label}: cuts cannot be negative"
    end
    if total_cut < MIN_CUT_S
      raise NothingToTrimError,
            "#{label}: #{(total_cut * 1000).round(1)}ms is below the #{(MIN_CUT_S * 1000).round}ms floor"
    end
    return unless [ head_cut, tail_cut ].max > MAX_CUT_S
    raise TrimTooLargeError,
          "#{label}: #{(([ head_cut, tail_cut ].max) * 1000).round}ms exceeds the " \
          "#{(MAX_CUT_S * 1000).round}ms limit - that is not encoder padding"
  end

  def validate_against_duration!
    return if kept_s > 1.0
    raise TrimTooLargeError,
          "#{label}: cutting #{total_cut.round(3)}s would leave #{kept_s.round(3)}s"
  end

  def total_cut
    head_cut + tail_cut
  end

  def original_duration_s
    @original_duration_s ||= probe("duration").to_f
  end

  def kept_s
    original_duration_s - total_cut
  end

  def bitrate
    @bitrate ||= begin
      raw = probe("bit_rate")
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def probe(entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=#{entry}",
      "-of", "csv=p=0", @original.path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip
  end

  def download_original
    @original = Tempfile.new([ "gapless_#{track.id}", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| @original.write(chunk) }
    @original.flush
  rescue ActiveStorage::FileNotFoundError
    raise MissingAudioError, "#{label}: blob #{track.mp3_audio.blob.key} is not in storage"
  end

  def output_path
    @output_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_gapless.mp3")
  end

  # No fades: the samples being removed are silence or encoder ringing, so the
  # audio on either side of the cut is already at the level it should be.
  def render_trimmed
    FileUtils.mkdir_p(OUTPUT_DIR)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @original.path,
      "-af", "atrim=start=#{format('%.4f', head_cut)}:" \
             "end=#{format('%.4f', original_duration_s - tail_cut)},asetpts=PTS-STARTPTS",
      "-map_metadata", "0", "-id3v2_version", "3",
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
      io: File.open(output_path), filename: track.friendly_filename,
      content_type: "audio/mpeg"
    )
    track.reload
    track.process_mp3_audio
  end

  def result
    {
      track_id: track.id,
      label:,
      title: track.title,
      url: track.url,
      original_duration_s: original_duration_s.round(3),
      trimmed_duration_s: kept_s.round(3),
      head_cut_s: head_cut.round(4),
      tail_cut_s: tail_cut.round(4),
      output_path: output_path.to_s,
      backup_path: @backup_path&.to_s,
      applied: !dry_run
    }
  end
end
