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
