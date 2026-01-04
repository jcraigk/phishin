class ChronologicalTrackNavigator < ApplicationService
  EXCLUDED_SETS = %w[S P].freeze

  param :track
  option :direction, default: -> { :next }

  def call
    case direction.to_sym
    when :next
      find_next_track
    when :prev, :previous
      find_previous_track
    else
      raise ArgumentError, "Invalid direction: #{direction}. Must be :next or :prev"
    end
  end

  private

  def find_next_track
    next_in_show || first_track_of_next_show || first_track_in_library
  end

  def find_previous_track
    previous_in_show || last_track_of_previous_show || last_track_in_library
  end

  def next_in_show
    show.tracks
        .where("position > ?", track.position)
        .where.not(set: EXCLUDED_SETS)
        .where.not(audio_status: "missing")
        .order(:position)
        .first
  end

  def previous_in_show
    show.tracks
        .where("position < ?", track.position)
        .where.not(set: EXCLUDED_SETS)
        .where.not(audio_status: "missing")
        .order(position: :desc)
        .first
  end

  def first_track_of_next_show
    next_show = Show.where("date > ?", show.date)
                    .with_audio
                    .order(:date)
                    .first
    return nil unless next_show

    next_show.tracks
             .where.not(set: EXCLUDED_SETS)
             .where.not(audio_status: "missing")
             .order(:position)
             .first
  end

  def last_track_of_previous_show
    prev_show = Show.where("date < ?", show.date)
                    .with_audio
                    .order(date: :desc)
                    .first
    return nil unless prev_show

    prev_show.tracks
             .where.not(set: EXCLUDED_SETS)
             .where.not(audio_status: "missing")
             .order(position: :desc)
             .first
  end

  def first_track_in_library
    Track.joins(:show)
         .merge(Show.with_audio)
         .where.not(tracks: { set: EXCLUDED_SETS })
         .where.not(tracks: { audio_status: "missing" })
         .order("shows.date ASC, tracks.position ASC")
         .first
  end

  def last_track_in_library
    Track.joins(:show)
         .merge(Show.with_audio)
         .where.not(tracks: { set: EXCLUDED_SETS })
         .where.not(tracks: { audio_status: "missing" })
         .order("shows.date DESC, tracks.position DESC")
         .first
  end

  def show
    track.show
  end

  class << self
    def first_track
      Track.joins(:show)
           .merge(Show.with_audio)
           .where.not(tracks: { set: EXCLUDED_SETS })
           .where.not(tracks: { audio_status: "missing" })
           .order("shows.date ASC, tracks.position ASC")
           .first
    end

    def last_track
      Track.joins(:show)
           .merge(Show.with_audio)
           .where.not(tracks: { set: EXCLUDED_SETS })
           .where.not(tracks: { audio_status: "missing" })
           .order("shows.date DESC, tracks.position DESC")
           .first
    end

    def playable_tracks_for_show(show)
      show.tracks
          .where.not(set: EXCLUDED_SETS)
          .where.not(audio_status: "missing")
          .order(:position)
    end

    def adjacent_show(show, direction:)
      case direction.to_sym
      when :next
        Show.where("date > ?", show.date).with_audio.order(:date).first
      when :prev, :previous
        Show.where("date < ?", show.date).with_audio.order(date: :desc).first
      end
    end
  end
end
