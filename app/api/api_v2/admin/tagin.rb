class ApiV2::Admin::Tagin < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    desc "Sync tagin tags from the spreadsheet", hidden: true
    post :tagin_sync do
      job = AdminJob.create!(kind: "tagin_sync")
      Admin::TaginSyncJob.perform_async(job.id)
      status 201
      { job_id: job.id }
    end
  end
end
