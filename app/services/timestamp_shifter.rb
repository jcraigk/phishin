class TimestampShifter < ApplicationService
  option :track
  option :delta_s
  option :new_duration_s
  option :reason

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

  def orphan_track_tag(track_tag, reason)
    at = track_tag.starts_at_second || track_tag.ends_at_second
    track_tag.update_columns(orphaned_at: Time.current, orphan_reason: reason)
    @orphaned << {
      "type" => "TrackTag", "id" => track_tag.id, "at" => at, "reason" => reason
    }
  end

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

  def presence_of(second) = second.to_i.positive? ? second : nil

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
