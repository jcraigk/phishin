class Admin::TrimJob
  include Sidekiq::Job

  MIN_CUT_S = 0.5

  def perform(track_id, admin_job_id, opts_json, apply)
    track = Track.find(track_id)
    admin_job = AdminJob.find(admin_job_id)
    opts = JSON.parse(opts_json).symbolize_keys

    admin_job.run! do
      result = AudioEdgeTrimService.call(
        track,
        trim_start: opts[:trim_start].to_f,
        trim_end: opts[:trim_end].to_f,
        fade_in: opts[:fade_in].to_f,
        fade_out: opts[:fade_out].to_f,
        min_cut: MIN_CUT_S,
        dry_run: !apply,
        admin_job:
      )
      admin_job.payload["audio_paths"] =
        [ AdminJobAudio.store(admin_job, result[:output_path]) ]
      admin_job.save!
    end
  end
end
