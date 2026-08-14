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
    end
  end
end
