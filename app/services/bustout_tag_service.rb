class BustoutTagService < ApplicationService
  MIN_GAP = 100

  param :show

  def call
    show.tracks.each do |track|
      track.songs_tracks.each do |songs_track|
        prev_perf_gap = songs_track.previous_performance_gap
        next unless prev_perf_gap && prev_perf_gap > MIN_GAP
        apply_bustout_tag(track, songs_track.song, prev_perf_gap)
      end
    end
  end

  private

  def apply_bustout_tag(track, song, gap)
    ttag = track.track_tags.find do
      it.tag == bustout_tag && it.notes&.include?(song.title)
    end || track.track_tags.build(tag: bustout_tag)
    ttag.notes = "First performance of #{song.title} in #{gap} shows"
    ttag.save!
  end

  def bustout_tag
    @bustout_tag ||= Tag.find_by!(name: "Bustout")
  end
end
