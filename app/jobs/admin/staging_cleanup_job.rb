class Admin::StagingCleanupJob
  include Sidekiq::Job

  def perform
    Admin::StagingDir.orphaned.each { FileUtils.rm_rf(it) }
  end
end
