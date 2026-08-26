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
  option :notes, default: -> { nil }
  option :dry_run, default: -> { false }

  OUTPUT_DIR = Rails.root.join("tmp/banter_scan/renders")

  class Error < StandardError; end

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
    return if before_track.nil? || after_track.nil?

    unless before_track.show_id == after_track.show_id
      raise Error, "#{label}: before-track is from a different show"
    end
    return if before_track.position == after_track.position + 1

    raise Error, "#{label}: expected #{before_track.title} right after " \
                 "#{after_track.title}, found position #{before_track.position}"
  end

  def render_mp3
    FileUtils.mkdir_p(OUTPUT_DIR)
    render_via_lame(output_path, [ "-i", source_path.to_s ])
  end

  def insert_track
    TrackInserter.new(
      date: show.date.to_s,
      position:,
      file: output_path.to_s,
      title:,
      song_id: song.id,
      set: anchor.set
    ).call
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
      set: anchor.set,
      after_title: after_track&.title,
      before_title: before_track&.title,
      output_path: output_path.to_s,
      track_id: applied? ? track.id : nil,
      url: applied? ? track.url : nil
    }
  end
end
