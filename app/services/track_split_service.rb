# Splits a track that holds several songs joined by segues ("Mike's Song > I Am
# Hydrogen > Weekapaug Groove") into one track per song at human-chosen cut
# points: renders each part with ffmpeg, backs up the original, rewrites the DB
# records, and carries over every piece of derived data (likes, tags, jam start,
# playlist entries).
#
# Any number of cuts is allowed, so a title with N songs becomes N tracks. The
# original keeps its id and position and becomes the first part; the rest are
# new tracks inserted after it.
#
# Gaps are NOT recomputed here. A show can hold several splits, and recomputing
# per split would work from a half-changed set list; lib/tasks/split_scan.rake
# runs GapService once per show after all of its splits are in, scoped to the
# songs those splits touched (see SplitScan.refresh_gaps).
#
# The filter chain matches trim_filters() in scripts/audio_edge_analysis.py for
# a fadeless trim, which is what the review page auditions - see
# spec/services/track_split_service_parity_spec.rb.
class TrackSplitService < ApplicationService
  include LameEncoding

  param :track
  option :cut_points
  option :dry_run, default: -> { false }
  option :song_overrides, default: -> { {} }
  option :tag_sides, default: -> { {} }
  # Titles and songs for each part, when the reviewer named them explicitly.
  # Both are positional and must cover every part; absent, they are derived from
  # the track's segued title.
  option :part_titles, default: -> { nil }
  option :song_ids, default: -> { nil }

  # Every part must be at least this long. A cut nearer either end, or two cuts
  # nearer each other, is a mis-click rather than a segue;
  # audio_split_analysis.py screens for the same bound.
  MIN_PART_S = 2.0
  OUTPUT_DIR = Rails.root.join("tmp/track_splits")
  BACKUP_DIR = Rails.root.join("tmp/track_split_backups")
  # Splits "A > B" and "A -> B" alike; mirrors SEGUE_RE in the scan script.
  SEGUE_RE = /\s*-?>\s*/

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class TitleError < Error; end
  class CutOutOfRangeError < Error; end

  class SongNotFoundError < Error
    attr_reader :part_title

    def initialize(message, part_title: nil)
      super(message)
      @part_title = part_title
    end
  end

  # Mirror of trim_filters() in scripts/audio_edge_analysis.py with both fades
  # off. The parts come from one continuous recording, so each cut is butt
  # joined - a fade would invent a boundary the audience never heard.
  def self.filters(start_s:, end_s: nil)
    chain = [ end_s ? format("atrim=start=%.2f:end=%.2f", start_s, end_s)
                    : format("atrim=start=%.2f", start_s) ]
    chain << "asetpts=PTS-STARTPTS"
  end

  def call
    validate!
    download_original
    ensure_cuts_in_range
    render_parts

    return result if dry_run

    backup_original
    apply!
    attach_audio
    result
  ensure
    @original&.close!
  end

  private

  def label
    "#{track.show.date} #{track.title}"
  end

  def cuts
    @cuts ||= Array(cut_points).map(&:to_f).sort
  end

  def part_count
    cuts.size + 1
  end

  # One title per part: the reviewer's, or the segued title's own pieces. A part
  # the title does not name (more cuts than songs) repeats the previous name,
  # which the reviewer is expected to correct.
  def titles
    @titles ||= begin
      given = Array(part_titles).map { it.to_s.strip }.reject(&:empty?)
      return given if given.size == part_count
      from_title = track.title.split(SEGUE_RE).map(&:strip).reject(&:empty?)
      Array.new(part_count) { |i| from_title[i] || from_title.last || track.title }
    end
  end

  def validate!
    # Every part is cut from the blob, so the attachment has to be really
    # there - audio_status is a column and can say "complete" after a purge.
    if track.missing_audio? || !track.mp3_audio.attached?
      raise MissingAudioError, "#{label} has no audio attached"
    end
    raise CutOutOfRangeError, "#{label}: no cut points given" if cuts.empty?
    if titles.size != part_count || titles.any?(&:blank?)
      raise TitleError, "#{label}: could not name all #{part_count} parts"
    end
    # Resolved before anything is rendered: a part with no song is the one
    # failure a human has to settle, and it should cost no ffmpeg time.
    songs
  end

  # The song each part belongs to. An explicit song_ids list wins; otherwise
  # prefer the songs already on the track - they are the curated association -
  # and fall back to the catalog by title for a part that was never associated.
  def songs
    @songs ||= begin
      given = Array(song_ids).compact
      if given.size == part_count
        given.map { Song.find_by(id: it) || raise(SongNotFoundError.new(
          "#{label}: no song with id #{it}")) }
      else
        titles.each_with_index.map { |t, i| song_for(t, i) }
      end
    end
  end

  def song_for(title, index)
    override_song(title) ||
      track.songs.find { it.title.downcase == title.downcase } ||
      Song.where("LOWER(title) = ?", title.downcase).first ||
      # A part the reviewer renamed no longer matches a song by title, so fall
      # back to the track's own songs in order. The review page offers a song
      # picker for the cases this cannot resolve.
      (renamed? ? track.songs.to_a[index] : nil) ||
      raise(SongNotFoundError.new(
        "#{label}: no song matches #{title.inspect}", part_title: title
      ))
  end

  # True when the reviewer supplied titles rather than using the track's own.
  def renamed?
    Array(part_titles).map { it.to_s.strip }.reject(&:empty?).size == part_count
  end

  def override_song(title)
    id = song_overrides.find { |k, _| k.to_s.downcase == title.downcase }&.last
    id && Song.find_by(id:)
  end

  def download_original
    @original = Tempfile.new([ "track_#{track.id}_original", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| @original.write(chunk) }
    @original.flush
  rescue ActiveStorage::FileNotFoundError
    # The row says the audio is attached but the file is gone from storage.
    # Typed, so the apply task records it as a failure alongside the others
    # rather than aborting the whole run.
    raise MissingAudioError,
          "#{label}: blob #{track.mp3_audio.blob.key} is not in storage"
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

  # The boundaries of every part, as [start, end] pairs over the whole track.
  def spans
    @spans ||= ([ 0.0 ] + cuts + [ duration_s ]).each_cons(2).to_a
  end

  def ensure_cuts_in_range
    short = spans.find { |from, to| (to - from) < MIN_PART_S }
    return unless short
    raise CutOutOfRangeError,
          "#{label}: cuts at #{cuts.map { it.round(1) }.join(', ')}s leave a part " \
          "under #{MIN_PART_S}s (track is #{duration_s.round(1)}s)"
  end

  def part_paths
    @part_paths ||= (1..part_count).map do |n|
      OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_part#{n}.mp3")
    end
  end

  def render_parts
    FileUtils.mkdir_p(OUTPUT_DIR)
    spans.each_with_index do |(from, to), i|
      last = i == part_count - 1
      render(self.class.filters(start_s: from, end_s: (to unless last)), part_paths[i])
    end
  end

  def render(filters, out_path)
    render_via_lame(out_path, [ "-i", @original.path, "-af", filters.join(",") ])
  end

  def backup_original
    FileUtils.mkdir_p(BACKUP_DIR)
    @backup_path = BACKUP_DIR.join(
      "#{track.show.date}_#{track.slug}_#{track.mp3_audio.blob.key}.mp3"
    )
    FileUtils.cp(@original.path, @backup_path)
  end

  def apply!
    ActiveRecord::Base.transaction do
      shift_later_positions
      build_new_tracks
      rewrite_original
      reslug_duplicate_titles
      copy_likes
      split_tags
      move_jam_start
      split_playlist_entries
    end
  end

  # Every part after the first. Slugs are parked, not computed: a part's title
  # may already belong to another track in the show, and the real numbering is
  # only knowable once every position and title is settled.
  def build_new_tracks
    @new_tracks = (1...part_count).map do |i|
      Track.create!(
        show: track.show,
        title: titles[i],
        songs: [ songs[i] ],
        position: track.position + i,
        set: track.set,
        exclude_from_stats: track.exclude_from_stats,
        slug: "tmp-#{track.id}-#{i}-#{SecureRandom.hex(4)}"
      )
    end
  end

  # Slug is parked for the same reason as build_new_tracks.
  def rewrite_original
    track.title = titles[0]
    track.songs = [ songs[0] ]
    track.slug = "tmp-#{track.id}-orig-#{SecureRandom.hex(4)}"
    track.save!
  end

  def reslug_duplicate_titles
    @reslugged = []
    siblings = track.show.tracks.reload.order(:position)
                    .select { |t| titles.any? { it.casecmp?(t.title) } }
    return if siblings.empty?

    was = siblings.to_h { [ it.id, it.slug ] }
    # Two phases: (show_id, slug) is unique, and the final slugs permute among
    # these same rows, so assigning them directly would collide with a row that
    # has not been renumbered yet.
    siblings.each_with_index do |sibling, i|
      sibling.update_columns(slug: "tmp-#{track.id}-r#{i}-#{SecureRandom.hex(4)}")
    end
    split_ids = [ track.id, *@new_tracks.map(&:id) ]
    siblings.each do |sibling|
      sibling.generate_slug(force: true)
      sibling.save!
      next if sibling.slug == was[sibling.id] || split_ids.include?(sibling.id)
      @reslugged << { track_id: sibling.id, from: was[sibling.id], to: sibling.slug }
    end
  end

  # Descending, so the unique (show_id, position) index is never violated
  # mid-loop. Same shape as TrackInserter#shift_track_positions.
  def shift_later_positions
    track.show.tracks
         .where(position: (track.position + 1)..)
         .order(position: :desc)
         .each { it.update!(position: it.position + part_count - 1) }
  end

  # Duplicated, not moved: a listener who liked the combined track liked every
  # song in it. Real records, so likes_count stays correct on each track.
  def copy_likes
    @likes_copied = track.likes.count
    track.likes.find_each do |like|
      @new_tracks.each do |t|
        Like.create!(likable: t, user: like.user, created_at: like.created_at)
      end
    end
  end

  # The part a moment in the original belongs to, and its offset within it.
  def part_index_for(seconds)
    spans.index { |from, to| seconds >= from && seconds < to } || part_count - 1
  end

  def part_record(index)
    index.zero? ? track : @new_tracks[index - 1]
  end

  # Timestamped tags follow the audio they describe; untimestamped ones (SBD and
  # friends) describe the whole recording, so every part gets them.
  def split_tags
    @tags_copied = 0
    @tags_removed = 0
    @notes = []
    track.track_tags.find_each do |tag|
      starts = tag.starts_at_second
      ends = tag.ends_at_second
      if starts.nil? && ends.nil?
        place_untimestamped_tag(tag)
        next
      end

      first_part = part_index_for(starts || 0)
      last_part = ends ? part_index_for(ends) : first_part
      if ends && last_part > first_part
        # A tag spanning a cut becomes one tag per part it covers, each clamped
        # to its own side. Reported, because a jam chart entry cut up is a
        # judgment call a human may want to revisit.
        (first_part..last_part).each do |i|
          from, to = spans[i]
          seg_start = [ (starts || 0), from ].max - from
          seg_end = [ ends, to ].min - from
          if i == first_part
            tag.update!(track: part_record(i),
                        starts_at_second: seg_start.round,
                        ends_at_second: seg_end.ceil)
          else
            copy_tag(tag, part_record(i),
                     starts_at_second: seg_start.round,
                     ends_at_second: seg_end.ceil)
          end
        end
        @notes << "tag '#{tag.tag.name}' spanned a cut and was split across " \
                  "#{last_part - first_part + 1} parts"
        next
      end
      next if first_part.zero?  # wholly in part 1: leave it alone
      move_tag(tag, part_record(first_part), spans[first_part][0])
    end
  end

  def move_tag(tag, target, offset)
    tag.update!(
      track: target,
      starts_at_second: tag.starts_at_second &&
        [ (tag.starts_at_second - offset).round, 0 ].max,
      ends_at_second: tag.ends_at_second &&
        [ (tag.ends_at_second - offset).round, 0 ].max
    )
    @tags_copied += 1
  end

  # The reviewer assigns each untimestamped tag to whichever parts it belongs
  # to. Part 0 is the original record, so keeping it there is a no-op and
  # dropping it means moving the tag onto the first part that did keep it.
  def place_untimestamped_tag(tag)
    parts = tag_parts_for(tag)
    if parts.empty?
      tag.destroy!
      @tags_removed += 1
      return
    end
    if parts.include?(0)
      parts.drop(1).each { copy_tag(tag, part_record(it)) }
    else
      move_tag(tag, part_record(parts.first), 0)
      parts.drop(1).each { copy_tag(tag, part_record(it)) }
    end
  end

  # Accepts a list of part indices, or the two-part vocabulary older exports
  # used. Anything unrecognised means every part, which is the default.
  def tag_parts_for(track_tag)
    name = track_tag.tag.name
    side = tag_sides.find { |k, _| k.to_s.casecmp?(name) }&.last
    all = (0...part_count).to_a
    case side
    when Array then side.map(&:to_i).select { all.include?(it) }.uniq.sort
    when "first" then [ 0 ]
    when "second" then [ 1 ]
    when "neither", "none" then []
    else all
    end
  end

  def copy_tag(tag, target, **overrides)
    TrackTag.create!(
      track: target, tag: tag.tag, notes: tag.notes, transcript: tag.transcript,
      starts_at_second: tag.starts_at_second, ends_at_second: tag.ends_at_second,
      **overrides
    )
    @tags_copied += 1
  end

  def move_jam_start
    jam = track.jam_starts_at_second
    return if jam.nil?
    i = part_index_for(jam)
    return if i.zero?
    track.update!(jam_starts_at_second: nil)
    part_record(i).update!(
      jam_starts_at_second: [ (jam - spans[i][0]).round, 0 ].max
    )
  end

  # A playlist entry for the combined track has to keep playing the same audio.
  # An excerpt living entirely in one part just repoints at that part; anything
  # covering a cut (including a whole-track entry) becomes consecutive entries
  # so the playlist plays through unchanged.
  def split_playlist_entries
    @playlist_entries = 0
    track.playlist_tracks.includes(:playlist).find_each do |entry|
      starts = entry.starts_at_second.to_i
      ends = entry.ends_at_second.to_i
      # A zero end means "to the end of the track", which now means the end of
      # the last part.
      real_end = ends.zero? ? duration_s : ends
      first_part = part_index_for(starts)
      last_part = part_index_for([ real_end - 0.001, starts ].max)

      if first_part == last_part
        next if first_part.zero?  # already correct as it stands
        offset = spans[first_part][0].round
        entry.update!(
          track: part_record(first_part),
          starts_at_second: starts - offset,
          ends_at_second: ends.zero? ? nil : ends - offset
        )
        @playlist_entries += 1
        next
      end

      # Clamp the entry to its first part, then append one entry per part it
      # continues into, in playlist order.
      first_from, first_to = spans[first_part]
      entry.update!(
        track: part_record(first_part),
        starts_at_second: (starts - first_from).round,
        ends_at_second: (first_to - first_from).round
      )
      @playlist_entries += 1
      ((first_part + 1)..last_part).each_with_index do |i, n|
        from, to = spans[i]
        shift_playlist_positions(entry.playlist, entry.position + n)
        PlaylistTrack.create!(
          playlist: entry.playlist,
          track: part_record(i),
          position: entry.position + n + 1,
          starts_at_second: nil,
          ends_at_second: (i == last_part && !ends.zero?) ? (ends - from).round : nil
        )
        @playlist_entries += 1
      end
    end
  end

  # Descending, so the unique (position, playlist_id) index holds throughout.
  def shift_playlist_positions(playlist, after)
    playlist.playlist_tracks
            .where(position: (after + 1)..)
            .order(position: :desc)
            .each { it.update!(position: it.position + 1) }
  end

  def attach_audio
    part_count.times { |i| attach(part_record(i), part_paths[i]) }
  end

  def attach(record, path)
    record.mp3_audio.attach(
      io: File.open(path), filename: record.friendly_filename,
      content_type: "audio/mpeg"
    )
    record.reload
    record.process_mp3_audio
  end

  def result
    {
      track_id: track.id,
      new_track_ids: (@new_tracks || []).map(&:id),
      label:,
      cut_points: cuts.map { it.round(1) },
      parts: part_count.times.map do |i|
        from, to = spans[i]
        {
          title: titles[i],
          path: part_paths[i].to_s,
          duration_s: (to - from).round(1),
          song_id: songs[i].id,
          url: (part_record(i).url unless dry_run)
        }
      end,
      backup_path: @backup_path&.to_s,
      song_ids: songs.map(&:id),
      likes_copied: @likes_copied.to_i,
      tags_copied: @tags_copied.to_i,
      tags_removed: @tags_removed.to_i,
      playlist_entries: @playlist_entries.to_i,
      notes: @notes || [],
      reslugged: @reslugged || [],
      applied: !dry_run
    }
  end
end
