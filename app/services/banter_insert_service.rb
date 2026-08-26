# Inserts a banter track from a source recording file (usually a FLAC pulled
# from the archive.org item the show was cut from): encodes it to the
# catalog's LAME settings, inserts it after a given track via TrackInserter,
# and tags it. Either anchor may be absent: with only before_track the file
# goes at the start of that track's set (its position), with only after_track
# at the end. With dry_run: true it only renders the MP3 for review.
# Fed by scripts/audio_banter_analysis.py through rake banter_scan:apply.
class BanterInsertService < ApplicationService
  include LameEncoding

  param :after_track
  option :source_path
  option :before_track, default: -> { nil }
  option :title, default: -> { "Banter" }
  option :song, default: -> { Song.find_by!(title: "Banter") }
  option :set, default: -> { nil }
  option :notes, default: -> { nil }
  option :dry_run, default: -> { false }

  OUTPUT_DIR = Rails.root.join("tmp/banter_scan/renders")

  class Error < StandardError; end
  class AlreadyInserted < Error; end

  def call
    validate!
    render_mp3
    return result unless applied?

    insert_track
    tag_track
    result
  end

  private

  def validate!
    raise Error, "No source file at #{source_path}" unless File.exist?(source_path.to_s)
    raise Error, "Need a track on at least one side" if after_track.nil? && before_track.nil?
    check_already_inserted!
    return if before_track.nil? || after_track.nil?

    unless before_track.show_id == after_track.show_id
      raise Error, "#{label}: before-track is from a different show"
    end
    return if before_track.position == after_track.position + 1

    raise Error, "#{label}: expected #{before_track.title} right after " \
                 "#{after_track.title}, found position #{before_track.position}"
  end

  # Re-running an export must not double up: the slot already holding a track
  # with this title and the source file's length is this file, inserted earlier.
  def check_already_inserted!
    # The earlier copy sits at the target slot, or - when only a before-track
    # anchors it - just ahead of that track (the insert pushed it down by one).
    slots = after_track ? [ position ] : [ position, position - 1 ]
    existing = show.tracks.where(position: slots, title:).find do |t|
      (t.duration - source_duration_ms).abs <= 500
    end
    return unless existing

    raise AlreadyInserted, "#{label}: already inserted as #{existing.url}"
  end

  def source_duration_ms
    out, _err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1", source_path.to_s
    )
    status.success? ? (out.to_f * 1000).round : 0
  end

  def render_mp3
    FileUtils.mkdir_p(OUTPUT_DIR)
    render_via_lame(output_path, [ "-i", source_path.to_s ])
  end

  # TrackInserter shifts the later positions before it saves the new row, so a
  # failure there (a slug collision, say) would otherwise leave a gap behind.
  # Not a transaction: Active Storage defers the upload until commit, and the
  # inserter analyzes the file straight after attaching it.
  def insert_track
    TrackInserter.new(
      date: show.date.to_s,
      position:,
      file: output_path.to_s,
      title:,
      song_id: song.id,
      set: set.presence || anchor.set
    ).call
  rescue StandardError
    unshift_positions unless show.tracks.reload.exists?(position:)
    raise
  end

  def unshift_positions
    show.tracks.where("position > ?", position).order(:position).each do |t|
      t.update_column(:position, t.position - 1)
    end
  end

  def tag_track
    track.track_tags.create!(tag: Tag.find_by!(name: "Banter"), notes: notes.presence)
    sbd = Tag.find_by(name: "SBD")
    return unless sbd && anchor.tags.include?(sbd)

    track.track_tags.create!(tag: sbd)
  end

  def track
    @track ||= show.tracks.reload.find_by!(position:)
  end

  # The track whose set and tags the new one inherits.
  def anchor
    after_track || before_track
  end

  def show
    anchor.show
  end

  def position
    after_track ? after_track.position + 1 : before_track.position
  end

  def applied?
    !dry_run
  end

  def output_path
    @output_path ||= OUTPUT_DIR.join(
      "#{show.date}_#{after_track ? 'after' : 'before'}_#{anchor.slug.presence || anchor.position}.mp3"
    )
  end

  # Named in LameEncoding's error messages.
  def label
    "#{show.date} banter #{after_track ? 'after' : 'before'} #{anchor.title}"
  end

  def result
    {
      applied: applied?,
      date: show.date.to_s,
      title:,
      song: song.title,
      position:,
      set: set.presence || anchor.set,
      after_title: after_track&.title,
      before_title: before_track&.title,
      output_path: output_path.to_s,
      track_id: applied? ? track.id : nil,
      url: applied? ? track.url : nil
    }
  end
end
