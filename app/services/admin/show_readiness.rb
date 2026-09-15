class Admin::ShowReadiness < ApplicationService
  param :show

  def call
    {
      ready: problems.empty?,
      issues: problems.map { |problem| problem[:message] },
      problems:
    }
  end

  private

  def problems
    @problems ||= show_problems + track_problems
  end

  def show_problems
    list = []
    list << show_problem("no_venue", "No venue assigned") if show.venue.blank?
    list << show_problem("no_tour", "No tour assigned") if show.tour.blank?
    list << show_problem("no_tracks", "No tracks") if tracks.none?
    unless show.cover_art.attached?
      list << show_problem("no_cover_art", "No cover art selected")
    end
    unless show.album_cover.attached?
      list << show_problem("no_album_cover", "No album cover composited")
    end
    list
  end

  def track_problems
    tracks.flat_map { |track| problems_for(track) }
  end

  def problems_for(track)
    list = []
    list << track_problem(track, "track_blank_title", "blank title") if track.title.blank?
    list << track_problem(track, "track_blank_set", "blank set") if track.set.blank?
    list << track_problem(track, "track_no_songs", "no songs") if track.songs.none?
    list.concat(audio_problems_for(track))
    list
  end

  def audio_problems_for(track)
    unless track.mp3_audio.attached?
      return [ track_problem(track, "track_no_audio", "no audio") ]
    end

    list = []
    if track.duration.to_i.zero?
      list << track_problem(track, "track_zero_duration", "zero duration")
    end
    unless track.png_waveform.attached?
      list << track_problem(track, "track_no_waveform", "no waveform")
    end
    if track.missing_audio?
      list << track_problem(track, "track_audio_unprocessed", "audio not processed")
    end
    list
  end

  def show_problem(code, message)
    { scope: "show", code:, message: }
  end

  def track_problem(track, code, detail)
    {
      scope: "track",
      code:,
      track_id: track.id,
      position: track.position,
      title: track.title,
      detail:,
      message: "#{track.position}. #{track.title}: #{detail}"
    }
  end

  def tracks
    @tracks ||= show.tracks
                    .order(:position)
                    .includes(:songs, :mp3_audio_attachment, :png_waveform_attachment)
                    .to_a
  end
end
