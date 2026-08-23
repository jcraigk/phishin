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
  include LameEncoding

  param :track
  option :head_cut, default: -> { 0.0 }
  option :tail_cut, default: -> { 0.0 }
  option :dry_run, default: -> { false }

  # A head cut is inferred from where the padding appears to end, so a large one
  # means the measurement drifted into the music. Encoder delay runs to tens of
  # milliseconds; beyond this the caller measured something else.
  MAX_HEAD_CUT_S = 0.25
  # A tail cut is only ever a run of samples that are exactly zero, which cannot
  # contain audio however long it runs. Some tracks end with the best part of a
  # second of digital black, so this is bounded only to catch a caller passing
  # something wild.
  MAX_TAIL_CUT_S = 5.0
  # Below this the re-encode costs more than the cut is worth.
  MIN_CUT_S = 0.004
  BYTES_PER_SAMPLE = 2
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
    if head_cut > MAX_HEAD_CUT_S
      raise TrimTooLargeError,
            "#{label}: head cut of #{(head_cut * 1000).round}ms exceeds the " \
            "#{(MAX_HEAD_CUT_S * 1000).round}ms limit - that is not encoder padding"
    end
    return unless tail_cut > MAX_TAIL_CUT_S
    raise TrimTooLargeError,
          "#{label}: tail cut of #{(tail_cut * 1000).round}ms exceeds the " \
          "#{(MAX_TAIL_CUT_S * 1000).round}ms limit"
  end

  def validate_against_duration!
    return if kept_s > 1.0
    raise TrimTooLargeError,
          "#{label}: cutting #{total_cut.round(3)}s would leave #{kept_s.round(3)}s"
  end

  def total_cut
    head_cut + tail_cut
  end

  # What the decoder yields, not what the container claims. An mp3 written
  # without a LAME header leaves ffprobe to estimate from the bitrate, and its
  # answer runs about 4ms long. Trimming against it left that much of the
  # padding in place on every track, which is a gap at the joint.
  def original_duration_s
    @original_duration_s ||= decoded_duration_s
  end

  def decoded_duration_s
    out, err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-i", @original.path,
      "-f", "s16le", "-acodec", "pcm_s16le", "-"
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
    out.bytesize / (BYTES_PER_SAMPLE * channels) / sample_rate.to_f
  end

  def sample_rate
    @sample_rate ||= stream_probe("sample_rate").to_i
  end

  def channels
    @channels ||= stream_probe("channels").to_i
  end

  def kept_s
    original_duration_s - total_cut
  end


  def probe(entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=#{entry}",
      "-of", "csv=p=0", @original.path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip
  end

  def stream_probe(entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-select_streams", "a:0",
      "-show_entries", "stream=#{entry}", "-of", "csv=p=0", @original.path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip.split("\n").first.to_s.split(",").first.to_s
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

  def render_trimmed
    FileUtils.mkdir_p(OUTPUT_DIR)
    render_via_lame(output_path, [
      "-i", @original.path,
      "-af", "atrim=start=#{format('%.6f', head_cut)}:" \
             "end=#{format('%.6f', original_duration_s - tail_cut)},asetpts=PTS-STARTPTS"
    ])
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
