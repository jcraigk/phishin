class Admin::StagingDir
  ROOT = Rails.root.join("tmp/staging")

  def self.orphaned
    return [] unless ROOT.exist?
    live = Show.joins(:staged_sources).distinct.pluck(:date).map(&:to_s)
    ROOT.children.select { it.directory? && !live.include?(it.basename.to_s) }
  end

  def initialize(show)
    @show = show
  end

  def root = ROOT.join(@show.date.to_s)

  def incoming = root.join("incoming")

  def sources_dir = root.join("sources")

  def proxies_dir = root.join("proxies")

  def renders_dir = root.join("renders")

  def timeline = root.join("timeline.flac")

  def source_path(source)
    sources_dir.join(format("%03d-%s", source.position, source.filename))
  end

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
