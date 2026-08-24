# Rewrites a run of adjacent tracks so they join without a gap or a tick.
#
# GaplessTrimService removes the encoder padding from a track's edges, which
# closes the 20-70ms dropout at a joint. What it cannot fix is the step that is
# left: two tracks recorded as one performance still meet at different sample
# levels, and butting them together is an audible click.
#
# Only a crossfade smooths that, and a crossfade needs both tracks at once. So
# the run is rendered as a single stream - each part trimmed, consecutive parts
# overlapped by FADE_S - and that stream is then cut back apart at the middle of
# each overlap. Every track keeps its own file; each carries half the blend; and
# concatenating them reproduces the crossfade exactly. That last property is the
# point, because it means the joint is fixed for someone who downloads the
# tracks and joins them, not only inside a player that could crossfade for
# itself.
#
# A run rather than a pair: a track in the middle of a segued sequence is faded
# at both ends, so its file depends on both of its neighbours and the whole run
# has to be rendered and saved together.
class GaplessJointService < ApplicationService
  include LameEncoding

  param :tracks
  # Per track id, { head:, tail: } in seconds - what the scan measured. Supplied
  # rather than derived: lib/tasks/gapless_scan.rake decides what is safe to
  # remove, this applies it.
  option :cuts
  option :dry_run, default: -> { false }

  # Long enough to smooth the step, short enough that each file gains only half
  # a millisecond of its neighbour. 5ms and 10ms were auditioned against it and
  # sounded no better, so the shortest that works is the one used.
  FADE_S = 0.002
  # Trimming a second track's padding sometimes uncovers a hard waveform edge
  # the short fade cannot span, and butting the two together then ticks. Such a
  # joint gets a wider fade instead - auditioned against keeping the padding,
  # which removes the tick but restores the very dropout the trim exists to
  # remove.
  WIDE_FADE_S = 0.02
  # How far the step at a joint stands out from the music around it: the size
  # of the jump over the local rms. Joints judged by ear separate at about
  # 0.25 - those that ticked measured 0.26 to 0.44, those that sounded clean
  # 0.17 to 0.20. The threshold sits below that because this is measured on the
  # trimmed sources, which reads a little lower than the rendered files it is
  # predicting: across the joints already surveyed, 0.22 widens every one that
  # ticked and none that did not.
  WIDE_FADE_RATIO = 0.22
  # A quiet passage can read a high ratio off a jump too small to hear, so the
  # step has to clear this as well before the fade is widened.
  WIDE_FADE_MIN_JUMP = 300
  # Samples either side of the seam the jump is measured across, and the window
  # the surrounding loudness is taken from.
  SEAM_SAMPLES = 40
  CONTEXT_SAMPLES = 4_410
  # A cut is only worth a re-encode above this. Far below GaplessTrimService's
  # floor, because a run is rewritten for the sake of its joints even where the
  # individual cuts are tiny.
  MIN_CUT_S = 0.0005
  # A head cut is inferred from where padding appears to end, so a large one
  # means the measurement drifted into the music.
  MAX_HEAD_CUT_S = 0.25
  MAX_TAIL_CUT_S = 5.0
  BYTES_PER_SAMPLE = 2
  RATE = 44_100
  OUTPUT_DIR = Rails.root.join("tmp/gapless_joints")
  BACKUP_DIR = GaplessTrimService::BACKUP_DIR
  BACKUP_BUDGET_BYTES = GaplessTrimService::BACKUP_BUDGET_BYTES

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class NotAdjacentError < Error; end
  class TrimTooLargeError < Error; end
  class BackupBudgetError < Error; end

  def call
    validate!
    download_sources
    render_run
    split_run

    return result if dry_run

    backup_sources
    replace_audio
    refresh_show
    result
  ensure
    @files&.each { it&.close! }
  end

  private

  def label
    "#{tracks.first.show.date} #{tracks.first.title}..#{tracks.last.title}"
  end

  def validate!
    raise NotAdjacentError, "a joint needs at least two tracks" if tracks.size < 2
    tracks.each_cons(2) do |left, right|
      next if left.show_id == right.show_id && left.set == right.set &&
              right.position == left.position + 1
      raise NotAdjacentError,
            "#{left.title} and #{right.title} are not adjacent in the same set"
    end
    tracks.each do |track|
      # Both checks: audio_status is a record of what should be there, the
      # attachment is what is. A track can claim complete audio and have no
      # blob, and downloading nothing fails much further in.
      next if !track.missing_audio? && track.mp3_audio.attached?
      raise MissingAudioError, "#{track.title} has no audio attached"
    end
    validate_cuts!
  end

  def validate_cuts!
    tracks.each do |track|
      head, tail = cut_for(track)
      if head.negative? || tail.negative?
        raise TrimTooLargeError, "#{track.title}: cuts cannot be negative"
      end
      if head > MAX_HEAD_CUT_S
        raise TrimTooLargeError,
              "#{track.title}: head cut of #{(head * 1000).round}ms is not encoder padding"
      end
      next unless tail > MAX_TAIL_CUT_S
      raise TrimTooLargeError,
            "#{track.title}: tail cut of #{(tail * 1000).round}ms exceeds the limit"
    end
  end

  def cut_for(track)
    cut = cuts[track.id] || {}
    [ cut[:head].to_f, cut[:tail].to_f ]
  end

  def download_sources
    @files = tracks.map do |track|
      file = Tempfile.new([ "joint_#{track.id}", ".mp3" ], binmode: true)
      track.mp3_audio.blob.download { |chunk| file.write(chunk) }
      file.flush
      file
    rescue ActiveStorage::FileNotFoundError
      raise MissingAudioError, "#{track.title}: blob is not in storage"
    end
  end

  # What the decoder yields, not what the container claims. An mp3 written
  # without a LAME header leaves ffprobe to estimate from the bitrate, and its
  # answer runs about 4ms long - enough to leave padding in place at the joint.
  def decoded_duration_s(path)
    out, err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-i", path.to_s,
      "-f", "s16le", "-acodec", "pcm_s16le", "-ac", "1", "-ar", RATE.to_s, "-"
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
    out.bytesize / BYTES_PER_SAMPLE / RATE.to_f
  end

  # What each part contributes to the run, after its own cuts.
  def segments
    @segments ||= tracks.zip(@files).map do |track, file|
      head, tail = cut_for(track)
      full = decoded_duration_s(file.path)
      finish = full - tail
      raise TrimTooLargeError, "#{track.title}: cutting would leave nothing" if finish - head < 1.0
      { track:, file:, start: head, finish:, kept: finish - head }
    end
  end

  # One stream: every part trimmed, consecutive parts overlapped.
  #
  # acrossfade takes exactly two inputs, so the overlaps chain pairwise - the
  # same shape TrackMergeService uses to merge three tracks in one pass.
  def render_run
    FileUtils.mkdir_p(OUTPUT_DIR)
    graph = segments.each_with_index.map { |seg, i| "#{segment_chain(seg, i)}[s#{i}]" }
    label_in = "s0"
    (1...segments.size).each do |i|
      out = i == segments.size - 1 ? "out" : "x#{i}"
      graph << "[#{label_in}][s#{i}]acrossfade=" \
               "d=#{fades[i - 1]}:c1=tri:c2=tri[#{out}]"
      label_in = out
    end
    run_ffmpeg(@files.flat_map { [ "-i", it.path ] } +
               [ "-filter_complex", graph.join(";"), "-map", "[out]",
                 "-f", "wav", "-acodec", "pcm_s16le", run_path.to_s ])
  end

  # One fade per joint, chosen from the step the trimmed edges actually meet at.
  # Measured here rather than taken from the scan because it is the trimmed
  # edges that matter, and the trim is applied in this pass.
  def fades
    @fades ||= segments.each_cons(2).map do |left, right|
      audible_step?(left, right) ? WIDE_FADE_S : FADE_S
    end
  end

  def audible_step?(left, right)
    tail = edge_samples(left, tail: true)
    head = edge_samples(right, tail: false)
    return false if tail.empty? || head.empty?
    seam = tail.last(SEAM_SAMPLES) + head.first(SEAM_SAMPLES)
    jump = seam.each_cons(2).map { (it[1] - it[0]).abs }.max.to_i
    return false if jump < WIDE_FADE_MIN_JUMP
    context = tail.last(CONTEXT_SAMPLES) + head.first(CONTEXT_SAMPLES)
    rms = Math.sqrt(context.sum { it * it }.fdiv(context.size))
    jump / [ rms, 1.0 ].max >= WIDE_FADE_RATIO
  end

  # The samples at one end of a segment, after its own cuts, as the crossfade
  # will see them.
  # atrim rather than -ss: seeking an mp3 lands on a frame boundary, which moves
  # the edge by up to a frame and reads the step at the wrong place.
  def edge_samples(seg, tail:)
    span = (SEAM_SAMPLES + CONTEXT_SAMPLES).fdiv(RATE)
    from, to =
      if tail
        [ [ seg[:finish] - span, seg[:start] ].max, seg[:finish] ]
      else
        [ seg[:start], [ seg[:start] + span, seg[:finish] ].min ]
      end
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-i", seg[:file].path,
      "-af", "atrim=start=#{format('%.7f', from)}:end=#{format('%.7f', to)}",
      "-f", "s16le", "-acodec", "pcm_s16le", "-ac", "1", "-ar", RATE.to_s, "-"
    )
    return [] unless status.success?
    out.unpack("s<*")
  end

  def segment_chain(seg, index)
    "[#{index}:a]atrim=start=#{format('%.7f', seg[:start])}:" \
      "end=#{format('%.7f', seg[:finish])},asetpts=PTS-STARTPTS,aresample=#{RATE}[t#{index}];" \
      "[t#{index}]aformat=channel_layouts=stereo"
  end

  def run_path
    @run_path ||= OUTPUT_DIR.join("#{tracks.first.show.date}_#{tracks.first.slug}_run.wav")
  end

  # Cut the rendered stream back into one file per track, at the middle of each
  # overlap. Each part is a whole file again; the blend is shared between the
  # two files that meet at it.
  def split_run
    FileUtils.mkdir_p(OUTPUT_DIR)
    @outputs = boundaries.each_cons(2).with_index.map do |(from, to), i|
      track = tracks[i]
      path = OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_joint.mp3")
      # atrim rather than -ss: seeking lands on a frame boundary, and a boundary
      # that misses by a frame puts the overlap in the wrong file.
      range = "start=#{format('%.7f', from)}"
      range += ":end=#{format('%.7f', to)}" if to
      render_via_lame(path, [
        "-i", run_path.to_s,
        "-af", "atrim=#{range},asetpts=PTS-STARTPTS"
      ])
      { track_id: track.id, title: track.title, path: path.to_s,
        seconds: (to || total_seconds) - from }
    end
  end

  # Where each file starts in the rendered stream. Every overlap after the first
  # part pulls the remaining boundaries earlier by half a fade.
  def boundaries
    @boundaries ||= begin
      marks = [ 0.0 ]
      running = 0.0
      spent = 0.0
      segments.each_with_index do |seg, i|
        running += seg[:kept]
        next if i == segments.size - 1
        # Each overlap so far has pulled the stream earlier by its whole width;
        # the boundary sits at the middle of the one being crossed now.
        spent += fades[i]
        marks << running - spent + (fades[i] / 2)
      end
      marks << nil
      marks
    end
  end

  def total_seconds
    @total_seconds ||= segments.sum { it[:kept] } - fades.sum
  end

  def check_backup_budget!
    used = GaplessTrimService.backup_bytes_used
    needed = @files.sum { File.size(it.path) }
    return if used + needed <= BACKUP_BUDGET_BYTES
    raise BackupBudgetError,
          "#{label}: backups hold #{(used / 1024.0**3).round(1)}GB of the " \
          "#{BACKUP_BUDGET_BYTES / 1024**3}GB budget - prune #{BACKUP_DIR} to continue"
  end

  # Raises before any attachment is touched, so a full budget leaves the run
  # exactly as it was rather than rewritten with no way back.
  def backup_sources
    check_backup_budget!
    FileUtils.mkdir_p(BACKUP_DIR)
    @backup_paths = tracks.zip(@files).map do |track, file|
      path = BACKUP_DIR.join("#{track.show.date}_#{track.slug}_#{track.mp3_audio.blob.key}.mp3")
      FileUtils.cp(file.path, path)
      path.to_s
    end
  end

  def replace_audio
    @outputs.each do |out|
      track = tracks.find { it.id == out[:track_id] }
      track.mp3_audio.attach(
        io: File.open(out[:path]), filename: track.friendly_filename,
        content_type: "audio/mpeg"
      )
      track.reload
      track.process_mp3_audio
      refresh_playlist_entries(track)
    end
  end

  # playlist_tracks.duration is a snapshot of the track's duration taken when
  # the entry was saved, and nothing invalidates it. Re-saving each entry walks
  # it and the playlist total back into agreement with the new audio.
  def refresh_playlist_entries(track)
    PlaylistTrack.where(track_id: track.id).find_each(&:save!)
  end

  # Once for the run rather than once per track: the per-track call sums an
  # association that may still hold the durations from before this rewrite.
  def refresh_show
    tracks.first.show.reload.save_duration
  end

  def result
    {
      label:,
      track_ids: tracks.map(&:id),
      outputs: @outputs,
      backup_paths: @backup_paths || [],
      fade_s: FADE_S,
      applied: !dry_run
    }
  end
end
