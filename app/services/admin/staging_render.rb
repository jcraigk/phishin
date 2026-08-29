# Renders one staged track from the lossless timeline to mp3. Builds its own
# ffmpeg arguments on purpose: AudioEdgeTrimService.filters and
# TrackSplitService.filters are parity-locked to the scan scripts, and staging
# must keep working when those are removed.
#
# Input seeking (-ss/-to before -i) rather than an atrim filter, because atrim
# decodes from the head of the file on every call and a three hour timeline
# would make each track cost minutes. The seek on flac is sample accurate.
#
# Fades use ffmpeg's default curve, which is linear. The browser preview ramps
# a GainNode linearly to match; spec/services/admin/staging_render_spec.rb and
# spec/javascript/staging_fade_parity_spec.js hold both sides to the same
# numbers.
class Admin::StagingRender
  include LameEncoding

  class Error < StandardError; end

  def self.ffmpeg_args(timeline:, track:)
    length = (track.end_s - track.start_s).to_f
    args = [ "-ss", format("%.3f", track.start_s), "-to", format("%.3f", track.end_s), "-i", timeline.to_s ]
    filters = []
    filters << format("afade=t=in:st=0:d=%.2f", track.fade_in_s) if track.fade_in_s.positive?
    if track.fade_out_s.positive?
      fade = [ track.fade_out_s.to_f, length ].min
      filters << format("afade=t=out:st=%.2f:d=%.2f", length - fade, fade)
    end
    filters.empty? ? args : args + [ "-af", filters.join(",") ]
  end

  def self.call(timeline:, track:, out_path:)
    new(timeline:, track:, out_path:).call
  end

  def initialize(timeline:, track:, out_path:)
    @timeline = timeline
    @track = track
    @out_path = out_path
  end

  def call
    FileUtils.mkdir_p(File.dirname(@out_path))
    render_via_lame(@out_path, self.class.ffmpeg_args(timeline: @timeline, track: @track))
    @out_path
  end

  private

  def label
    "#{@track.show.date} #{@track.title}"
  end
end
