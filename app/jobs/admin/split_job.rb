class Admin::SplitJob
  include Sidekiq::Job

  def perform(track_id, admin_job_id, cut_s, apply)
    track = Track.find(track_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      result = TrackSplitService.call(track, cut_s: cut_s.to_f, dry_run: !apply)
      admin_job.payload["audio_paths"] = [
        AdminJobAudio.store(admin_job, result[:part1_path], index: 0),
        AdminJobAudio.store(admin_job, result[:part2_path], index: 1)
      ]
      admin_job.payload["new_track_id"] = result[:new_track_id]
      admin_job.save!
    end
  end
end
