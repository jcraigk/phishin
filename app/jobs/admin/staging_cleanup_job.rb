# Backstop for the synchronous cleanup commit and discard do themselves.
class Admin::StagingCleanupJob
  include Sidekiq::Job

  def perform
    Admin::StagingDir.orphaned.each { FileUtils.rm_rf(it) }
  end
end
