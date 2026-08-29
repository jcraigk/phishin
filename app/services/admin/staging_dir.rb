# Every path under a show's staging directory, in one place. Paths derive from
# the date and row positions rather than being stored, so the layout is
# knowable from the database alone.
class Admin::StagingDir
  ROOT = Rails.root.join("tmp/staging")

  def initialize(show)
    @show = show
  end

  def root = ROOT.join(@show.date.to_s)

  # Where uploads land and archives unpack, before the audio is sorted into
  # numbered sources.
  def incoming = root.join("incoming")

  def sources_dir = root.join("sources")

  def proxies_dir = root.join("proxies")

  def renders_dir = root.join("renders")

  def timeline = root.join("timeline.flac")

  def source_path(source)
    sources_dir.join(format("%03d-%s", source.position, source.filename))
  end

  # An mp3 source is its own proxy: it is already what the browser can play.
  def proxy_path(source)
    return source_path(source) if source.mp3?
    proxies_dir.join(format("%03d.mp3", source.position))
  end

  def render_path(track)
    renders_dir.join(format("%03d.mp3", track.position))
  end

  def reset!
    remove!
    [ incoming, sources_dir, proxies_dir, renders_dir ].each { FileUtils.mkdir_p(it) }
  end

  def remove!
    FileUtils.rm_rf(root)
  end
end
