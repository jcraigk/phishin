class ApiV2::Admin::Jobs < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :jobs do
      desc "Fetch an admin job's status", hidden: true
      params do
        requires :id, type: Integer
      end
      get ":id" do
        job = AdminJob.find(params[:id])
        {
          id: job.id,
          kind: job.kind,
          status: job.status,
          progress: job.progress,
          message: job.message,
          payload: job.payload,
          show_id: job.show_id,
          track_id: job.track_id
        }
      end

      # Audio auditioning for every admin job that renders a file. Admin-gated like
      # the rest of this class: it serves raw audio off the filesystem.
      desc "Stream rendered audio from a job", hidden: true
      params do
        requires :id, type: Integer
        optional :index, type: Integer, default: 0
      end
      get ":id/audio" do
        job = AdminJob.find(params[:id])
        path = job.payload.fetch("audio_paths", [])[params[:index]]
        error!({ message: "No rendered audio" }, 404) if path.blank? || !File.exist?(path)

        # The API formats JSON globally, so the body is handed to Rack directly
        # rather than returned from the block, which would encode it as a string.
        content_type "audio/mpeg"
        header "Content-Length", File.size(path).to_s
        header "Accept-Ranges", "none"
        env["api.format"] = :binary
        body File.binread(path)
      end
    end
  end
end
