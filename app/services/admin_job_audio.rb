module AdminJobAudio
  RETENTION = 7.days

  class MissingRenderError < StandardError; end

  def self.dir
    ENV["IN_DOCKER"] ? Pathname.new("/content/admin_job_audio") : Rails.root.join("tmp/admin_job_audio")
  end

  def self.store(admin_job, source_path, index: 0)
    unless source_path.present? && File.exist?(source_path)
      raise MissingRenderError, "No rendered audio at #{source_path.inspect}"
    end

    FileUtils.mkdir_p(dir)
    destination = path_for(admin_job, index)
    FileUtils.cp(source_path, destination)
    destination.to_s
  end

  def self.path_for(admin_job, index)
    dir.join("#{admin_job.id}_#{index}.mp3")
  end

  def self.prune(older_than: RETENTION)
    return 0 unless dir.exist?
    cutoff = Time.current - older_than
    Dir.glob(dir.join("*.mp3")).count do |path|
      File.mtime(path) < cutoff && File.delete(path).positive?
    end
  end
end
