require "typhoeus"

class RegenerateTrackWaveformJob
  include Sidekiq::Job

  attr_reader :track_id

  def perform(track_id)
    @track_id = track_id

    return unless track

    track.generate_waveform_image(purge_cache: true)
  end

  private

  def track
    @track ||= Track.find_by(id: @track_id)
  end
end
