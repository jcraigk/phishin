# Splits a track that holds two songs joined by a segue ("Mike's Song > I Am
# Hydrogen") into two tracks at a human-chosen cut point: renders both halves
# with ffmpeg, backs up the original, rewrites the DB records, and carries over
# every piece of derived data (likes, tags, jam start, playlist entries).
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
  param :track
  option :cut_s
  option :dry_run, default: -> { false }
  option :song_overrides, default: -> { {} }
  option :tag_sides, default: -> { {} }

  # Both halves must be at least this long. A cut nearer either end is a
  # mis-click, not a segue; audio_split_analysis.py screens for the same bound.
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
  # off. The two halves come from one continuous recording, so the cut is butt
  # joined - a fade would invent a boundary the audience never heard.
  def self.filters(start_s:, end_s: nil)
    chain = [ end_s ? format("atrim=start=%.2f:end=%.2f", start_s, end_s)
                    : format("atrim=start=%.2f", start_s) ]
    chain << "asetpts=PTS-STARTPTS"
  end

  def call
    validate!
    download_original
    ensure_cut_in_range
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

  def part_titles
    @part_titles ||= track.title.split(SEGUE_RE, 2).map(&:strip)
  end

  def validate!
    # Both halves are cut from the blob, so the attachment has to be really
    # there - audio_status is a column and can say "complete" after a purge.
    if track.missing_audio? || !track.mp3_audio.attached?
      raise MissingAudioError, "#{label} has no audio attached"
    end

    if track.title.count(">") != 1
      raise TitleError,
            "#{label}: title needs exactly one '>' to split (found " \
            "#{track.title.count('>')})"
    end
    if part_titles.size != 2 || part_titles.any?(&:blank?)
      raise TitleError, "#{label}: title does not split into two named parts"
    end
    # Resolved before anything is rendered: a part with no song is the one
    # failure a human has to settle, and it should cost no ffmpeg time.
    songs
  end

  # The song each half belongs to. Prefer the songs already on the track - they
  # are the curated association - and fall back to the catalog by title for the
  # case where a part was never associated (e.g. a renamed jam).
  def songs
    @songs ||= part_titles.map do |title|
      override_song(title) ||
        track.songs.find { it.title.downcase == title.downcase } ||
        Song.where("LOWER(title) = ?", title.downcase).first ||
        raise(SongNotFoundError.new(
          "#{label}: no song matches #{title.inspect}", part_title: title
        ))
    end
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

  def bitrate
    @bitrate ||= begin
      raw = probe(@original.path, "bit_rate")
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

  def ensure_cut_in_range
    return if cut_s > MIN_PART_S && cut_s < duration_s - MIN_PART_S
    raise CutOutOfRangeError,
          "#{label}: cut at #{cut_s.round(1)}s leaves a part under #{MIN_PART_S}s " \
          "(track is #{duration_s.round(1)}s)"
  end

  def part_paths
    @part_paths ||= [ 1, 2 ].map do |n|
      OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_part#{n}.mp3")
    end
  end

  def render_parts
    FileUtils.mkdir_p(OUTPUT_DIR)
    render(self.class.filters(start_s: 0.0, end_s: cut_s), part_paths[0])
    render(self.class.filters(start_s: cut_s), part_paths[1])
  end

  def render(filters, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @original.path,
      "-af", filters.join(","), "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, out_path.to_s
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

  def apply!
    ActiveRecord::Base.transaction do
      shift_later_positions
      @new_track = build_second_track
      rewrite_original
      reslug_duplicate_titles
      copy_likes
      split_tags
      move_jam_start
      split_playlist_entries
    end
  end

  def reslug_duplicate_titles
    @reslugged = []
    siblings = track.show.tracks.reload.order(:position)
                    .select { part_titles[1].casecmp?(it.title) }
    return if siblings.size < 2

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
      next if sibling.slug == was[sibling.id]
      @reslugged << { track_id: sibling.id, from: was[sibling.id], to: sibling.slug }
    end
  end

  # Descending, so the unique (show_id, position) index is never violated
  # mid-loop. Same shape as TrackInserter#shift_track_positions.
  def shift_later_positions
    track.show.tracks
         .where(position: (track.position + 1)..)
         .order(position: :desc)
         .each { it.update!(position: it.position + 1) }
  end

  def build_second_track
    Track.create!(
      show: track.show,
      title: part_titles[1],
      songs: [ songs[1] ],
      position: track.position + 1,
      set: track.set,
      exclude_from_stats: track.exclude_from_stats
    )
  end

  # The original keeps its position and its id, so anything pointing at it (a
  # like, a playlist) still resolves. Its slug is regenerated from the new
  # title, which is why external links to the combined track break.
  def rewrite_original
    track.title = part_titles[0]
    track.songs = [ songs[0] ]
    track.generate_slug(force: true)
    track.save!
  end

  # Duplicated, not moved: a listener who liked the combined track liked both
  # songs in it. Real records, so likes_count stays correct on both tracks.
  def copy_likes
    @likes_copied = track.likes.count
    track.likes.find_each do |like|
      Like.create!(likable: @new_track, user: like.user, created_at: like.created_at)
    end
  end

  # Timestamped tags follow the audio they describe; untimestamped ones (SBD and
  # friends) describe the whole recording, so both halves get them.
  def split_tags
    @tags_copied = 0
    @tags_removed = 0
    @notes = []
    cut = cut_s
    track.track_tags.find_each do |tag|
      starts = tag.starts_at_second
      ends = tag.ends_at_second
      if starts.nil? && ends.nil?
        case tag_side_for(tag)
        when "first"
          nil
        when "second"
          tag.update!(track: @new_track)
          @tags_copied += 1
        when "neither"
          tag.destroy!
          @tags_removed += 1
        else
          copy_tag(tag)
        end
        next
      end
      if ends && starts && starts < cut && ends > cut
        # A tag spanning the cut becomes one tag per half, each clamped to its
        # own side. Reported, because a jam chart entry cut in two is a judgment
        # call a human may want to revisit.
        tag.update!(ends_at_second: cut.floor)
        copy_tag(tag, starts_at_second: 0, ends_at_second: (ends - cut).ceil)
        @notes << "tag '#{tag.tag.name}' spanned the cut and was split in two"
        next
      end
      next if starts && starts < cut   # wholly in part 1: leave it alone
      # Wholly in part 2: move it across, rebased onto the new track's clock.
      tag.update!(
        track: @new_track,
        starts_at_second: starts && [ (starts - cut).round, 0 ].max,
        ends_at_second: ends && [ (ends - cut).round, 0 ].max
      )
      @tags_copied += 1
    end
  end

  def tag_side_for(track_tag)
    name = track_tag.tag.name
    tag_sides.find { |k, _| k.to_s.casecmp?(name) }&.last
  end

  def copy_tag(tag, **overrides)
    TrackTag.create!(
      track: @new_track, tag: tag.tag, notes: tag.notes, transcript: tag.transcript,
      starts_at_second: tag.starts_at_second, ends_at_second: tag.ends_at_second,
      **overrides
    )
    @tags_copied += 1
  end

  def move_jam_start
    jam = track.jam_starts_at_second
    return if jam.nil? || jam < cut_s
    track.update!(jam_starts_at_second: nil)
    @new_track.update!(jam_starts_at_second: [ (jam - cut_s).round, 0 ].max)
  end

  # A playlist entry for the combined track has to keep playing the same audio.
  # An excerpt living entirely in one half just repoints at that half; anything
  # covering the cut (including a whole-track entry) becomes two consecutive
  # entries so the playlist plays through unchanged.
  def split_playlist_entries
    @playlist_entries = 0
    cut = cut_s.round
    track.playlist_tracks.includes(:playlist).find_each do |entry|
      starts = entry.starts_at_second.to_i
      ends = entry.ends_at_second.to_i
      # A zero end means "to the end of the track", which now means the end of
      # part 2 - so it spans the cut like a full-track entry does.
      spans = ends.zero? ? starts < cut : (starts < cut && ends > cut)
      if !spans && starts >= cut
        entry.update!(
          track: @new_track,
          starts_at_second: starts - cut,
          ends_at_second: ends.zero? ? nil : ends - cut
        )
        @playlist_entries += 1
        next
      end
      next unless spans  # wholly in part 1: still correct as it stands
      # Clamp this entry to part 1 and add its remainder as the next entry.
      entry.update!(ends_at_second: cut)
      shift_playlist_positions(entry.playlist, entry.position)
      PlaylistTrack.create!(
        playlist: entry.playlist,
        track: @new_track,
        position: entry.position + 1,
        starts_at_second: nil,
        ends_at_second: ends.zero? ? nil : ends - cut
      )
      @playlist_entries += 2
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
    attach(track, part_paths[0])
    attach(@new_track, part_paths[1])
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
      new_track_id: @new_track&.id,
      label:,
      part1_title: part_titles[0],
      part2_title: part_titles[1],
      part1_path: part_paths[0].to_s,
      part2_path: part_paths[1].to_s,
      part1_duration_s: cut_s.round(1),
      part2_duration_s: (duration_s - cut_s).round(1),
      backup_path: @backup_path&.to_s,
      song_ids: songs.map(&:id),
      part1_url: (track.url if @new_track),
      part2_url: @new_track&.url,
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
