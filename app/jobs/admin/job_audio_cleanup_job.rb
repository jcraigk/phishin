# Sweeps audio renders that admin jobs stored for auditioning. Auditions happen
# while an admin is at the console, so anything past the retention window is a
# leftover rather than something still in use.
class Admin::JobAudioCleanupJob
  include Sidekiq::Job

  def perform
    AdminJobAudio.prune
  end
end
