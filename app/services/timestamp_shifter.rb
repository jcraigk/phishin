# The single place that decides what happens to a timestamped child when a
# track's audio changes.
#
# Three kinds of child carry an offset into a track's audio: a TrackTag's
# starts/ends window, a Track's own jam_starts_at_second, and a PlaylistTrack
# excerpt's bounds. Four operations (trim, shift boundary, replace audio,
# concat) used to change the audio under all three and move none of them, which
# is the bug this exists to fix. Split and combine already move them correctly
# and deliberately do NOT call this - see the note at the bottom.
#
#   TimestampShifter.call(track:, delta_s:, new_duration_s:, reason:)
#   => { shifted: [...], clamped: [...], orphaned: [...] }
#
# delta_s is added to every offset on the track: -3.0 for a 3s head trim, 0.0
# for a tail trim (nothing moved, but the audio got shorter), nil for a
# wholesale replacement. new_duration_s is the length of the audio AFTER the
# operation, in seconds.
#
# The rules, applied in this order to each window:
#
#   1. delta_s nil - the offsets cannot be mapped onto audio nobody has
#      measured, so everything timestamped on the track is orphaned.
#   2. The shifted window lands wholly inside [0, new_duration_s] - SHIFTED.
#   3. The shifted START falls before 0 or after new_duration_s - ORPHANED. The
#      row is kept, its numbers are kept, and orphaned_at/orphan_reason are set.
#      Its subject is gone; guessing a new position would invent a claim the tag
#      never made.
#   4. The window merely OVERLAPS an edge - its start survives but its end runs
#      past the new end - CLAMPED to the surviving range and shifted. Part of it
#      still describes real audio, so it is reported separately from an orphan:
#      a clamp is a narrowed truth, an orphan is a lost one.
#
# Every decision comes back in one summarizing hash:
# shifted/clamped entries carry type/id/from/to, orphaned entries carry
# type/id/at/reason.
class TimestampShifter < ApplicationService
  option :track
  option :delta_s
  option :new_duration_s
  option :reason

  # Written to track_tags.orphan_reason and returned in the orphaned entries.
  # A fixed vocabulary so the review queue can group and explain them.
  REASON_UNMAPPABLE = "audio_replaced"
  REASON_BEFORE_START = "before_new_start"
  REASON_PAST_END = "past_new_end"

  def call
    @shifted = []
    @clamped = []
    @orphaned = []

    ActiveRecord::Base.transaction do
      shift_track_tags
      shift_jam_start
      shift_playlist_tracks
    end

    { shifted: @shifted, clamped: @clamped, orphaned: @orphaned }
  end

  private

  # Offsets are stored as whole seconds everywhere, so a fractional delta is
  # rounded once here rather than separately per child - otherwise a tag and the
  # jam start on the same track could round apart and drift by a second.
  def delta
    @delta ||= delta_s&.round
  end

  def unmappable? = delta_s.nil?

  def max_s = new_duration_s&.round

  def shift_track_tags
    track.track_tags.where.not(starts_at_second: nil).or(
      track.track_tags.where.not(ends_at_second: nil)
    ).find_each { decide_track_tag(it) }
  end

  def decide_track_tag(track_tag)
    outcome = classify(track_tag.starts_at_second, track_tag.ends_at_second)

    case outcome[:verdict]
    when :orphan
      orphan_track_tag(track_tag, outcome[:reason])
    else
      from = track_tag.starts_at_second
      track_tag.update!(
        starts_at_second: outcome[:starts], ends_at_second: outcome[:ends]
      )
      record(outcome[:verdict], "TrackTag", track_tag.id, from, outcome[:starts])
    end
  end

  # The row survives with its numbers untouched. Only the flag is written, and
  # only through update_columns: an orphaned tag is evidence, and running
  # validations or touch callbacks over it here would be the app editing the
  # very record it is trying to preserve.
  def orphan_track_tag(track_tag, reason)
    at = track_tag.starts_at_second || track_tag.ends_at_second
    track_tag.update_columns(orphaned_at: Time.current, orphan_reason: reason)
    @orphaned << {
      "type" => "TrackTag", "id" => track_tag.id, "at" => at, "reason" => reason
    }
  end

  # A jam start is a single point, not a window, so it can only shift or
  # orphan - there is no partial overlap to clamp. It lives on the track rather
  # than on a row of its own, so orphaning clears the column: leaving a stale
  # offset would keep pointing listeners at the wrong moment, and the original
  # value is preserved in the returned summary instead.
  def shift_jam_start
    jam = track.jam_starts_at_second
    return if jam.nil?

    outcome = classify(jam, nil)
    if outcome[:verdict] == :orphan
      track.update!(jam_starts_at_second: nil)
      @orphaned << {
        "type" => "Track", "id" => track.id, "at" => jam,
        "reason" => outcome[:reason], "field" => "jam_starts_at_second"
      }
      return
    end

    track.update!(jam_starts_at_second: outcome[:starts])
    record(outcome[:verdict], "Track", track.id, jam, outcome[:starts])
  end

  # A playlist excerpt is USER-OWNED, and nobody but its owner can act on a flag
  # set on it, so it is clamped and never orphan-flagged - see the note at the
  # bottom of this file. Its nil/zero bounds mean "from the top" and "to the
  # end", which are relative to whatever audio the track holds now and therefore
  # already correct after any edit; only real offsets move.
  def shift_playlist_tracks
    track.playlist_tracks.find_each { decide_playlist_track(it) }
  end

  def decide_playlist_track(entry)
    starts = presence_of(entry.starts_at_second)
    ends = presence_of(entry.ends_at_second)
    return if starts.nil? && ends.nil?

    outcome = classify(starts, ends, clamp_only: true)
    entry.update!(
      starts_at_second: outcome[:starts] || entry.starts_at_second,
      ends_at_second: outcome[:ends]
    )
    record(outcome[:verdict], "PlaylistTrack", entry.id, starts, outcome[:starts])
  end

  # PlaylistTrack stores "no bound" as either nil or 0 depending on how the
  # entry was made; both mean the same thing to excerpt_duration.
  def presence_of(second) = second.to_i.positive? ? second : nil

  # The whole ruleset, over one window, in one place. Returns the verdict plus
  # the new numbers, and never writes anything - so the same rules can be read
  # once and applied to three different kinds of record.
  #
  # clamp_only downgrades an orphan to a clamp for children that must keep
  # playing something rather than be flagged for review.
  def classify(starts, ends, clamp_only: false)
    return { verdict: :orphan, reason: REASON_UNMAPPABLE } if unmappable?

    new_start = starts.nil? ? nil : starts + delta
    new_end = ends.nil? ? nil : ends + delta

    if new_start&.negative?
      return clamped_to_range(new_start, new_end) if clamp_only
      return { verdict: :orphan, reason: REASON_BEFORE_START }
    end

    if max_s && new_start && new_start > max_s
      return clamped_to_range(new_start, new_end) if clamp_only
      return { verdict: :orphan, reason: REASON_PAST_END }
    end

    # The start survives but the end does not: the window still describes real
    # audio up to the new end, so it is narrowed to what survives.
    if max_s && new_end && new_end > max_s
      return { verdict: :clamped, starts: new_start, ends: max_s }
    end

    { verdict: :shifted, starts: new_start, ends: new_end }
  end

  def clamped_to_range(new_start, new_end)
    lo = new_start.nil? ? nil : new_start.clamp(0, max_s || new_start)
    hi = new_end.nil? ? nil : new_end.clamp(lo || 0, max_s || new_end)
    { verdict: :clamped, starts: lo, ends: hi }
  end

  def record(verdict, type, id, from, to)
    entry = { "type" => type, "id" => id, "from" => from, "to" => to }
    verdict == :clamped ? @clamped << entry : @shifted << entry
  end
end

# WHY TrackSplitService DOES NOT CALL THIS
#
# TrackSplitService#split_tags was read closely before this service was written.
# It applies a rule this one deliberately does not have: a window is not just
# moved on one track's clock, it is REPARENTED to a different track. A tag
# spanning the cut becomes TWO tags, one per half, and an untimestamped tag is
# copied to both. Those are decisions about which track a tag belongs to, and
# this service only ever answers where on one track's clock a window lands.
#
# The offset arithmetic they share with rule 1 is a single addition
# (starts - cut). Routing it through here would mean teaching this service about
# a second track and about splitting one row into two, to save that addition - a
# bigger abstraction with more semantics than the duplication it removes, and
# the split specs pin behavior this service would change. So the reparenting
# stays where it is.
#
# Splitting is CLI-only (lib/tasks/split_scan.rake). The admin UI moves an
# existing boundary and never creates or removes one, so nothing in the browser
# reaches that reparenting path.
