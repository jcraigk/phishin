class TrackConcatService < ApplicationService
  option :tracks
  option :dry_run, default: -> { false }

  OUTPUT_DIR = Rails.root.join("tmp/track_concats")

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class TooFewTracksError < Error; end
  class ShowMismatchError < Error; end

  def call
    validate!
    download_sources
    render_joined
    result
  ensure
    @sources&.each(&:close!)
    @list_file&.close!
  end

  private

  def validate!
    raise TooFewTracksError, "concat needs at least 2 tracks (got #{tracks.size})" if tracks.size < 2

    missing = tracks.reject { it.mp3_audio.attached? }
    if missing.any?
      raise MissingAudioError,
            "no audio attached: #{missing.map { label(it) }.join(', ')}"
    end

    show_ids = tracks.map(&:show_id).uniq
    return if show_ids.size == 1
    raise ShowMismatchError, "tracks span shows #{show_ids.sort.join(', ')}"
  end

  def label(track = tracks.first)
    "#{track.show.date} #{track.title}"
  end

  def download_sources
    @sources = tracks.map do |track|
      file = Tempfile.new([ "track_#{track.id}_concat", ".mp3" ], binmode: true)
      track.mp3_audio.blob.download { |chunk| file.write(chunk) }
      file.flush
      file
    rescue ActiveStorage::FileNotFoundError
      raise MissingAudioError,
            "#{label(track)}: blob #{track.mp3_audio.blob.key} is not in storage"
    end
  end

  def source_durations
    @source_durations ||= @sources.map { probe(it.path, "duration").to_f }
  end

  def source_bitrates
    @source_bitrates ||= @sources.map do |file|
      raw = probe(file.path, "bit_rate")
      /\A\d+\z/.match?(raw) ? (raw.to_i / 1000.0).round : nil
    end
  end

  def source_codecs
    @source_codecs ||= @sources.map { probe_stream(it.path, "codec_name") }
  end

  def probe(path, entry)
    capture_probe("format=#{entry}", path)
  end

  def probe_stream(path, entry)
    capture_probe("stream=#{entry}", path)
  end

  def capture_probe(entries, path)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", entries,
      "-of", "csv=p=0", path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip.lines.first.to_s.strip
  end

  def reencode?
    source_bitrates.any?(&:nil?) ||
      source_bitrates.uniq.size > 1 ||
      source_codecs.uniq.size > 1
  end

  def bitrate
    "#{source_bitrates.compact.max || 192}k"
  end

  def output_path
    @output_path ||=
      if dry_run
        @output_tempfile = Tempfile.new([ "track_concat_#{tracks.first.id}", ".mp3" ])
        @output_tempfile.close
        Pathname.new(@output_tempfile.path)
      else
        FileUtils.mkdir_p(OUTPUT_DIR)
        OUTPUT_DIR.join("#{tracks.first.show.date}_#{tracks.first.slug}_joined.mp3")
      end
  end

  def list_path
    @list_path ||= begin
      @list_file = Tempfile.new([ "concat_list", ".txt" ])
      @list_file.write(@sources.map { "file '#{it.path}'\n" }.join)
      @list_file.flush
      @list_file.path
    end
  end

  def render_joined
    args =
      if reencode?
        [ "-f", "concat", "-safe", "0", "-i", list_path,
          "-b:a", bitrate, "-id3v2_version", "3" ]
      else
        [ "-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy" ]
      end
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", *args, output_path.to_s
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
  end

  def duration_s
    @duration_s ||= probe(output_path.to_s, "duration").to_f
  end

  def result
    {
      track_ids: tracks.map(&:id),
      label:,
      output_path: output_path.to_s,
      duration_s: duration_s.round(1),
      source_durations: source_durations.map { it.round(1) },
      reencoded: reencode?,
      bitrate: reencode? ? bitrate : nil,
      applied: !dry_run
    }
  end
end
