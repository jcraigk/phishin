# Merges two or three adjacent tracks into one: concatenates their audio with
# ffmpeg in a single pass, backs up every source, keeps the first track's record
# and removes the rest, and carries over every piece of derived data (likes,
# tags, jam start, playlist entries) with the absorbed tracks' timestamps
# rebased onto the merged clock.
#
# The inverse of TrackSplitService. Written for sandwiches stored as separate
# tracks - "Hold Your Head Up" + "Terrapin > Hold Your Head Up", or the
# three-track "HYHU" + "Bike" + "HYHU" - which should be one track.
#
# Gaps are NOT recomputed here; lib/tasks/sandwich_scan.rake runs GapService once
# per show after all of its merges are in, scoped to the songs involved.
class TrackMergeService < ApplicationService
  param :track
  option :second
  # A three-track sandwich ("HYHU > Bike > HYHU") is merged in one pass rather
  # than by calling this service twice. Two calls render an intermediate mp3 and
  # tag it on the way through, and Id3TagService rewrites through Mp3Info, which
  # does not carry the Xing gapless header and appends ~45ms of decoder padding.
  # Feeding that back in put the padding between the two joints as an audible
  # dropout. One pass also means one encode instead of two for the first parts.
  option :third, default: -> { nil }
  option :title
  option :dry_run, default: -> { false }

  # Dropped from the end of the first track when it ends in an encoder flush
  # burst; see render_merged and tail_burst?. Measured bursts run 1.25-1.36ms,
  # so 3ms clears them with room to spare and is still far below audibility.
  TAIL_TRIM_S = 0.003
  # The burst is detected within this much of the boundary. Wider than the trim,
  # and wide enough to cover a re-encoded file: an mp3 encoder appends padding
  # after the burst, leaving it ~16ms from the end rather than at it.
  BURST_PROBE_S = 0.030
  # A burst is loud in absolute terms AND louder than the music leading up to
  # it. The level alone is not enough: a track ending at full volume reaches it
  # with ordinary music. Measured bursts run 2.8x the surrounding level and
  # above, while the loudest clean endings sit below 0.7x.
  TAIL_BURST_LEVEL = 20_000
  TAIL_BURST_RATIO = 1.5
  # The stretch before the edge that a burst is compared against.
  BURST_BODY_S = 0.5
  # Decoded from the end to reach the last millisecond; a whole file decode
  # would cost seconds per merge for the same answer.
  TAIL_PROBE_S = 0.5
  # A burst is a run of spikes with brief dips between them. Walking back from
  # its last spike, this many consecutive quiet samples means the burst has
  # ended and the music behind it has started.
  QUIET_RUN = 64
  BURST_EDGE_LEVEL = 8_000
  # Never drop more than this from a joint, however far back the burst appears
  # to run. Beyond it the cut is removing audio, not an artifact.
  MAX_TRIM_S = 0.004
  # A butt cut between two non-zero samples clicks. Most joints do not need
  # help: the two sides already meet at a similar level. Where they do not, a
  # fade this long removes the step - short enough that nobody hears a fade,
  # long enough to reach zero smoothly.
  FADE_S = 0.005
  # How far apart the two sides have to be, as a ratio of their loudness over
  # FADE_S, before a joint gets faded. Ordinary joints measure within ~5%.
  FADE_RATIO = 1.25
  # Below this there is no audible step to smooth, whatever the ratio says.
  FADE_FLOOR = 500
  # Bursts are measured on interleaved stereo, so a window in seconds covers
  # this many samples per second of audio.
  CHANNELS = 2
  OUTPUT_DIR = Rails.root.join("tmp/track_merges")
  BACKUP_DIR = Rails.root.join("tmp/track_merge_backups")

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class TitleError < Error; end
  class NotAdjacentError < Error; end

  def call
    validate!
    @first_title = track.title
    @second_title = second.title
    @third_title = third&.title
    download_sources
    render_merged

    return result if dry_run

    backup_sources
    apply!
    attach_audio
    result
  ensure
    @files&.each { it&.close! }
  end

  private

  # Every track being merged, in playing order.
  def parts
    @parts ||= [ track, second, third ].compact
  end

  # The ones folded into the first, which are removed once the merge applies.
  def absorbed
    @absorbed ||= parts.drop(1)
  end

  def label
    "#{track.show.date} #{parts.map(&:title).join(' + ')}"
  end

  def validate!
    raise TitleError, "#{label}: merged title is blank" if title.to_s.strip.empty?

    parts.each_cons(2) do |left, right|
      unless left.show_id == right.show_id
        raise NotAdjacentError, "#{label}: tracks are in different shows"
      end
      unless left.set == right.set
        raise NotAdjacentError,
              "#{label}: tracks are in different sets (#{left.set} and #{right.set})"
      end
      unless right.position == left.position + 1
        raise NotAdjacentError,
              "#{label}: tracks are not adjacent (positions #{left.position} " \
              "and #{right.position})"
      end
    end
    parts.each do |t|
      if t.missing_audio? || !t.mp3_audio.attached?
        raise MissingAudioError, "#{label}: #{t.title.inspect} has no audio attached"
      end
    end
  end

  def download_sources
    @files = parts.each_with_index.map { |t, i| download(t, "part#{i}") }
    @first_file, @second_file, @third_file = @files
  end

  def download(record, which)
    file = Tempfile.new([ "track_#{record.id}_#{which}", ".mp3" ], binmode: true)
    record.mp3_audio.blob.download { |chunk| file.write(chunk) }
    file.flush
    file
  rescue ActiveStorage::FileNotFoundError
    raise MissingAudioError,
          "#{label}: blob #{record.mp3_audio.blob.key} is not in storage"
  end

  def part_durations
    @part_durations ||= @files.map { probe(it.path, "duration").to_f }
  end

  def first_duration_s
    part_durations[0]
  end

  def second_duration_s
    part_durations[1]
  end

  def third_duration_s
    part_durations[2]
  end

  def bitrate
    @bitrate ||= begin
      raw = probe(@first_file.path, "bit_rate")
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def probe(path, entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=#{entry}",
      "-of", "csv=p=0", path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip
  end

  def output_path
    @output_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_merged.mp3")
  end

  # Butt joined, no crossfade: the two tracks are consecutive audio from one
  # recording, so anything else would invent a transition.
  #
  # Some files end with a burst of encoder flush at full scale that the LAME
  # header does not cover. It is inaudible at the end of a track, but once
  # another track follows it, it is a loud click. Where it is present the last
  # millisecond is dropped, which is far below what anyone can hear; where it is
  # not, the audio is joined untouched.
  def render_merged
    FileUtils.mkdir_p(OUTPUT_DIR)
    plan = trim_plan
    chains = plan.each_with_index.map { |seg, i| segment_chain(seg, i) }
    # A crossfade, not a fade on each side. Two independent fades ramp both
    # sides to zero and leave a hole at the joint; a crossfade overlaps them, so
    # the level moves from one track to the other without ever dropping out.
    #
    # Crossfades chain pairwise because acrossfade takes exactly two inputs;
    # where no joint needs one, a single concat joins everything at once.
    @joint_fades = joint_fades(plan)
    graph = chains.each_with_index.map { |c, i| "#{c}[s#{i}]" }
    if @joint_fades.any?
      label_in = "s0"
      @joint_fades.each_with_index do |faded, i|
        out = i == @joint_fades.size - 1 ? "out" : "x#{i}"
        graph << if faded
                   "[#{label_in}][s#{i + 1}]acrossfade=d=#{FADE_S}:c1=tri:c2=tri[#{out}]"
        else
                   "[#{label_in}][s#{i + 1}]concat=n=2:v=0:a=1[#{out}]"
        end
        label_in = out
      end
    else
      inputs = (0...plan.size).map { "[s#{it}]" }.join
      graph << "#{inputs}concat=n=#{plan.size}:v=0:a=1[out]"
    end

    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error",
      *@files.flat_map { [ "-i", it.path ] },
      "-filter_complex", graph.join(";"),
      "-map", "[out]", "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, output_path.to_s
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
  end

  # What to cut from each part before joining. A burst at a joint is trimmed off
  # whichever side carries it; the head of the first part and the tail of the
  # last are the edges of the merged track, so only the last part's tail burst
  # matters there (re-encoding turns its padding into ordinary audio).
  def trim_plan
    @trim_plan ||= @files.each_with_index.map do |file, i|
      first = i.zero?
      last = i == @files.size - 1
      tail_burst = tail_burst?(file.path)
      head_burst = !first && head_burst?(file.path)
      start = head_burst ? TAIL_TRIM_S : 0.0
      finish = ([ trim_point(file.path), 0.0 ].max if tail_burst)
      { file:, start:, finish:, tail_burst:, head_burst:, first:, last: }
    end.tap do |plan|
      @tail_trimmed = plan.first[:tail_burst]
      @head_trimmed = plan[1] ? plan[1][:head_burst] : false
      @second_tail_trimmed = plan[1] ? plan[1][:tail_burst] : false
      @trimmed_parts = plan.count { it[:tail_burst] || it[:head_burst] }
    end
  end

  def segment_chain(seg, index)
    chain =
      if seg[:start].positive? || seg[:finish]
        range = "start=#{format('%.4f', seg[:start])}"
        range += ":end=#{format('%.4f', seg[:finish])}" if seg[:finish]
        "[#{index}:a]atrim=#{range},asetpts=PTS-STARTPTS,aresample=44100"
      else
        "[#{index}:a]aresample=44100"
      end
    # Only the final part's tail is the end of the merged track.
    return chain unless seg[:last]
    @end_faded = loud_tail?(tail_pcm(seg[:file].path, seg[:finish]))
    return chain unless @end_faded
    st = fade_start(seg[:finish], seg[:file].path, seg[:start])
    "#{chain},afade=t=out:st=#{format('%.4f', st)}:d=#{FADE_S}"
  end

  # A joint only gets a fade when the two sides actually meet at different
  # levels.
  def joint_fades(plan)
    fades = plan.each_cons(2).map do |left, right|
      level_step?(
        tail_pcm(left[:file].path, left[:finish]),
        head_pcm(right[:file].path, right[:start])
      )
    end
    @joint_faded = fades.any?
    fades
  end

  # The mirror of tail_burst?: the same artifact can sit at the head of a file,
  # where it is inaudible on its own but a click once another track runs into it.
  def head_burst?(path)
    out, err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-i", path.to_s,
      "-t", format("%.4f", BURST_BODY_S), "-f", "s16le", "-acodec", "pcm_s16le",
      "-ar", "44100", "-"
    )
    raise Error, "#{label}: ffmpeg failed reading the head of #{path}: #{err[0, 200]}" \
      unless status.success?
    burst?(out)
  end

  # True when the file's final millisecond reaches a level real music does not,
  # which is the encoder flush burst rather than the performance.
  #
  # Seeks from the end rather than to an absolute position: an -ss seek lands on
  # a frame boundary and decodes past the burst, reporting silence.
  def tail_burst?(path)
    out, err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-sseof", format("-%.2f", TAIL_PROBE_S),
      "-i", path.to_s, "-f", "s16le", "-acodec", "pcm_s16le",
      "-ar", "44100", "-"
    )
    raise Error, "#{label}: ffmpeg failed reading the tail of #{path}: #{err[0, 200]}" \
      unless status.success?
    burst?(out, from_end: true)
  end

  # A burst at the edge of `pcm`: loud on its own, and loud relative to the
  # music behind it. Measured per channel rather than downmixed, because a burst
  # can sit in one channel and averaging the two pulls it under the threshold.
  def burst?(pcm, from_end: false)
    samples = pcm.unpack("s<*")
    raise Error, "#{label}: no audio decoded while looking for a burst" if samples.empty?
    edge_n = (BURST_PROBE_S * 44_100).ceil * CHANNELS
    edge = from_end ? samples.last(edge_n) : samples.first(edge_n)
    # Whatever was decoded beyond the edge is the body. Sized from the decoded
    # samples rather than BURST_BODY_S: -sseof returns a window of frames, not
    # of seconds, so assuming a length here reaches back into the edge itself.
    rest_n = [ samples.size - edge_n, 0 ].max
    rest = from_end ? samples.first(rest_n) : samples.last(rest_n)
    return false if edge.blank? || rest.blank?
    body_n = (BURST_BODY_S * 44_100).ceil * CHANNELS
    body = from_end ? rest.last(body_n) : rest.first(body_n)
    peak = peak_of(edge)
    peak >= TAIL_BURST_LEVEL && peak >= peak_of(body) * TAIL_BURST_RATIO
  end

  def peak_of(samples)
    samples.max { |a, b| a.abs <=> b.abs }.abs
  end

  # Decoded audio for the last FADE_S of a segment, or the first FADE_S of one.
  #
  # The tail is taken by decoding from the end rather than seeking to an
  # absolute position: an -ss seek lands on a frame boundary and can decode past
  # the audio entirely, reporting silence where the music is.
  def tail_pcm(path, finish = nil)
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-sseof", format("-%.2f", TAIL_PROBE_S),
      "-i", path.to_s, "-f", "s16le", "-acodec", "pcm_s16le", "-ar", "44100", "-"
    )
    return [] unless status.success?
    samples = out.unpack("s<*")
    # Ignore anything the trim is going to remove.
    total = decoded_duration_s(path)
    drop = finish ? ((total - finish) * 44_100).round * CHANNELS : 0
    kept = drop.positive? ? samples.first([ samples.size - drop, 0 ].max) : samples
    kept.last((FADE_S * 44_100).ceil * CHANNELS)
  end

  def head_pcm(path, start = 0.0)
    pcm(path, start, FADE_S)
  end

  def pcm(path, start, duration)
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-ss", format("%.4f", start),
      "-t", format("%.4f", duration), "-i", path.to_s, "-f", "s16le",
      "-acodec", "pcm_s16le", "-ar", "44100", "-"
    )
    status.success? ? out.unpack("s<*") : []
  end

  def rms(samples)
    return 0.0 if samples.empty?
    Math.sqrt(samples.sum { it.to_f * it } / samples.size)
  end

  # The two sides of a joint meeting at audibly different levels.
  def level_step?(before, after)
    a = rms(before)
    b = rms(after)
    return false if [ a, b ].max < FADE_FLOOR
    ratio = [ a, b ].max / [ [ a, b ].min, 1.0 ].max
    ratio >= FADE_RATIO
  end

  # Audio still playing where the track stops, which cuts off as a click.
  def loud_tail?(samples)
    rms(samples) >= FADE_FLOOR
  end

  # afade needs a start time within the trimmed segment, which atrim has already
  # rebased to zero.
  def fade_start(finish, path, start = 0.0)
    finish ||= decoded_duration_s(path)
    [ finish - start - FADE_S, 0.0 ].max
  end

  # Where to cut so the burst goes with it. A burst sits at the very end of an
  # original file but ~16ms in on a re-encoded one, where the encoder appended
  # padding after it, so the cut follows the burst rather than a fixed offset.
  def trim_point(path)
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-sseof", format("-%.2f", TAIL_PROBE_S),
      "-i", path.to_s, "-f", "s16le", "-acodec", "pcm_s16le",
      "-ar", "44100", "-"
    )
    total = decoded_duration_s(path)
    return total - TAIL_TRIM_S unless status.success?
    samples = out.unpack("s<*")
    window = (BURST_PROBE_S * 44_100).ceil * CHANNELS
    edge = samples.last(window)
    last = edge.rindex { it.abs >= TAIL_BURST_LEVEL }
    return total - TAIL_TRIM_S if last.nil?
    # Walk back to where the burst starts. Cutting from the last loud sample
    # would leave the rest of it in; cutting a fixed distance from the end of
    # the file would take the music before it out.
    first = last
    quiet = 0
    while first.positive? && quiet < QUIET_RUN
      first -= 1
      quiet = edge[first].abs >= BURST_EDGE_LEVEL ? 0 : quiet + 1
    end
    # Capped: a real burst is a millisecond or two. A longer walk-back means it
    # ran into encoder padding (which some ffmpeg builds leave decodable) and
    # then into the music behind it, and cutting all of that leaves a hole.
    from_end = [ (edge.size - first) / CHANNELS / 44_100.0, MAX_TRIM_S ].min
    total - from_end
  end

  # Length of the audio ffmpeg actually decodes, measured by decoding it.
  #
  # Not ffprobe's reported duration: for a file carrying LAME gapless headers,
  # some ffprobe builds report the untrimmed length while the decoder yields the
  # trimmed one (57ms apart on ffmpeg 7.1.4, identical on 8.1.1). An atrim end
  # computed from the reported value then lands past the end of the stream and
  # silently cuts nothing. This measures the same stream atrim will see, so the
  # two cannot disagree.
  def decoded_duration_s(path)
    out, err, status = Open3.capture3(
      "ffmpeg", "-v", "error", "-i", path.to_s, "-f", "s16le",
      "-acodec", "pcm_s16le", "-ac", "1", "-ar", "44100", "-"
    )
    raise Error, "#{label}: ffmpeg failed measuring #{path}: #{err[0, 200]}" \
      unless status.success?
    out.bytesize / 2.0 / 44_100
  end

  def backup_sources
    FileUtils.mkdir_p(BACKUP_DIR)
    @backup_paths = parts.zip(@files).map do |t, file|
      path = BACKUP_DIR.join("#{t.show.date}_#{t.slug}_#{t.mp3_audio.blob.key}.mp3")
      FileUtils.cp(file.path, path)
      path.to_s
    end
  end

  def apply!
    ActiveRecord::Base.transaction do
      @likes_moved = 0
      @tags_moved = 0
      @playlist_entries = 0
      @notes = []
      # Each absorbed track starts where everything before it ends, so its
      # timestamps rebase onto the running total rather than onto the first
      # track's duration alone.
      offset = first_duration_s
      absorbed.each_with_index do |absorbee, i|
        @offset = offset
        move_likes(absorbee)
        move_tags(absorbee)
        move_jam_start(absorbee)
        move_playlist_entries(absorbee)
        offset += part_durations[i + 1]
      end
      rewrite_first
      @removed_id = second.id
      @removed_track_ids = absorbed.map(&:id)
      # Highest position first: each destroy is followed by closing the gap it
      # left, and removing from the end keeps the lower positions stable.
      absorbed.sort_by(&:position).reverse_each do |absorbee|
        position = absorbee.position
        absorbee.reload.destroy!
        close_position_gap(position)
      end
      reslug_duplicate_titles
    end
  end

  # A listener who liked either half liked the sandwich, but a user who liked
  # both must not end up with two likes on one track.
  def move_likes(absorbee)
    existing = track.likes.pluck(:user_id).to_set
    absorbee.likes.find_each do |like|
      next if existing.include?(like.user_id)
      like.update!(likable: track)
      existing << like.user_id
      @likes_moved += 1
    end
  end

  # Timestamps on an absorbed track are relative to its own start, which in the
  # merged track begins where everything before it ended.
  def move_tags(absorbee)
    seen = track.track_tags.filter_map do |tt|
      tt.tag_id if tt.starts_at_second.nil? && tt.ends_at_second.nil?
    end.to_set
    absorbee.track_tags.find_each do |tt|
      if tt.starts_at_second.nil? && tt.ends_at_second.nil?
        next tt.destroy! if seen.include?(tt.tag_id)
        seen << tt.tag_id
      end
      tt.update!(
        track:,
        starts_at_second: tt.starts_at_second && (tt.starts_at_second + @offset).round,
        ends_at_second: tt.ends_at_second && (tt.ends_at_second + @offset).round
      )
      @tags_moved += 1
    end
  end

  def move_jam_start(absorbee)
    return if track.jam_starts_at_second.present?
    jam = absorbee.jam_starts_at_second
    return if jam.nil?
    track.update!(jam_starts_at_second: (jam + @offset).round)
  end

  # An entry for an absorbed part now points at the merged track. Where a
  # playlist held the parts back to back, the pair becomes one entry so the
  # playlist plays the same audio without repeating it.
  def move_playlist_entries(absorbee)
    absorbee.playlist_tracks.includes(:playlist).find_each do |entry|
      prev = entry.playlist.playlist_tracks
                  .find_by(position: entry.position - 1, track_id: track.id)
      if prev && whole_track?(prev) && whole_track?(entry)
        entry.destroy!
        @notes << "playlist '#{entry.playlist.name}' held both halves; " \
                  "collapsed into one entry"
        next
      end
      entry.update!(
        track:,
        starts_at_second: (entry.starts_at_second || 0) + @offset.round,
        ends_at_second: entry.ends_at_second && (entry.ends_at_second + @offset).round
      )
      @playlist_entries += 1
    end
  end

  def whole_track?(entry)
    entry.starts_at_second.to_i.zero? && entry.ends_at_second.nil?
  end

  # Slug is parked, not computed: the merged title may already belong to another
  # track in the show. reslug_duplicate_titles assigns the real one.
  def rewrite_first
    track.title = title.strip
    track.songs = merged_songs
    track.slug = "tmp-#{track.id}-merge-#{SecureRandom.hex(4)}"
    track.save!
  end

  # The union of every part's songs, in playing order. A sandwich carries the
  # outer song once, the same as one that was never split.
  def merged_songs
    parts.flat_map { it.songs.to_a }.uniq
  end

  def close_position_gap(from)
    track.show.tracks.reload
         .where(position: from..)
         .order(position: :asc)
         .each { it.update!(position: it.position - 1) }
  end

  def reslug_duplicate_titles
    @reslugged = []
    siblings = track.show.tracks.reload.order(:position)
                    .select { track.title.casecmp?(it.title) }
    return if siblings.empty?

    was = siblings.to_h { [ it.id, it.slug ] }
    # Two phases: (show_id, slug) is unique, and the final slugs permute among
    # these same rows, so assigning them directly would collide with a row that
    # has not been renumbered yet.
    siblings.each_with_index do |sibling, i|
      sibling.update_columns(slug: "tmp-#{track.id}-#{i}-#{SecureRandom.hex(4)}")
    end
    siblings.each do |sibling|
      sibling.generate_slug(force: true)
      sibling.save!
      next if sibling.slug == was[sibling.id] || sibling.id == track.id
      @reslugged << { track_id: sibling.id, from: was[sibling.id], to: sibling.slug }
    end
  end

  def attach_audio
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
      removed_track_id: (@removed_id unless dry_run),
      removed_track_ids: (@removed_track_ids || [] unless dry_run),
      label:,
      title: title.strip,
      first_title: @first_title,
      second_title: @second_title,
      third_title: @third_title,
      first_duration_s: first_duration_s.round(1),
      second_duration_s: second_duration_s.round(1),
      third_duration_s: third_duration_s&.round(1),
      merged_duration_s: part_durations.sum.round(1),
      output_path: output_path.to_s,
      backup_paths: @backup_paths || [],
      song_ids: (dry_run ? merged_songs : track.songs).map(&:id),
      url: (track.url unless dry_run),
      likes_moved: @likes_moved.to_i,
      tags_moved: @tags_moved.to_i,
      playlist_entries: @playlist_entries.to_i,
      reslugged: @reslugged || [],
      notes: @notes || [],
      tail_trimmed: @tail_trimmed || false,
      head_trimmed: @head_trimmed || false,
      second_tail_trimmed: @second_tail_trimmed || false,
      joint_faded: @joint_faded || false,
      end_faded: @end_faded || false,
      applied: !dry_run
    }
  end
end
