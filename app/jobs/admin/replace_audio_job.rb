class Admin::ReplaceAudioJob
  include Sidekiq::Job

  def perform(track_id, admin_job_id, signed_id)
    track = Track.find(track_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      backup_path = TrackAudioReplacer.call(track:, blob:)
      admin_job.payload["backup_path"] = backup_path if backup_path
      admin_job.save!
    end
  end
end
