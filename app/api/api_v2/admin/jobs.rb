class ApiV2::Admin::Jobs < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :jobs do
      desc "List recent admin jobs", hidden: true
      params do
        optional :limit, type: Integer, default: 20, values: 1..100
      end
      get do
        jobs = AdminJob.order(created_at: :desc, id: :desc)
                       .limit(params[:limit])
                       .includes(:show)
        { jobs: jobs.map { |job| job_payload(job) } }
      end

      desc "Fetch an admin job's status", hidden: true
      params do
        requires :id, type: Integer
      end
      get ":id" do
        job_payload(AdminJob.find(params[:id]))
      end

      desc "Stream rendered audio from a job", hidden: true
      params do
        requires :id, type: Integer
        optional :index, type: Integer, default: 0
      end
      get ":id/audio" do
        job = AdminJob.find(params[:id])
        path = job.payload.fetch("audio_paths", [])[params[:index]]
        error!({ message: "No rendered audio" }, 404) if path.blank? || !File.exist?(path)

        content_type "audio/mpeg"
        header "Content-Length", File.size(path).to_s
        header "Accept-Ranges", "none"
        env["api.format"] = :binary
        body File.binread(path)
      end
    end
  end

  helpers do
    def job_payload(job)
      {
        id: job.id,
        kind: job.kind,
        status: job.status,
        progress: job.progress,
        message: job.message,
        payload: job.payload,
        show_id: job.show_id,
        show_date: job.show&.date&.to_s,
        track_id: job.track_id,
        created_at: job.created_at,
        updated_at: job.updated_at
      }
    end
  end
end
