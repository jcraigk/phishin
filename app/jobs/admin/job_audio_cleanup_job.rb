class Admin::JobAudioCleanupJob
  include Sidekiq::Job

  def perform
    AdminJobAudio.prune
  end
end
