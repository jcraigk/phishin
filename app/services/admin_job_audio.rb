# Durable storage for audio an admin job rendered so it can be auditioned later.
#
# Audio services render to a path keyed by the track (for example
# AudioEdgeTrimService writes "<date>_<slug>_trimmed.mp3"), which means the next
# render on the same track overwrites it. A preview that streamed straight from
# that path would serve whatever rendered most recently rather than what the job
# produced. Copying the bytes to a job-scoped path at the moment the job still
# holds them keeps each audition stable for the life of the job.
module AdminJobAudio
  DIR = Rails.root.join("tmp/admin_job_audio")
  RETENTION = 7.days

  class MissingRenderError < StandardError; end

  # Copies a freshly rendered file into job-scoped storage and returns the
  # stored path to record in the job payload.
  def self.store(admin_job, source_path, index: 0)
    unless source_path.present? && File.exist?(source_path)
      raise MissingRenderError, "No rendered audio at #{source_path.inspect}"
    end

    FileUtils.mkdir_p(DIR)
    destination = path_for(admin_job, index)
    FileUtils.cp(source_path, destination)
    destination.to_s
  end

  def self.path_for(admin_job, index)
    DIR.join("#{admin_job.id}_#{index}.mp3")
  end

  # Auditions are short-lived, so stored renders are swept once they age out.
  def self.prune(older_than: RETENTION)
    return 0 unless DIR.exist?
    cutoff = Time.current - older_than
    Dir.glob(DIR.join("*.mp3")).count do |path|
      File.mtime(path) < cutoff && File.delete(path).positive?
    end
  end
end
