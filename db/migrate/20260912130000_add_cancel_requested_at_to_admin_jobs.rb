class AddCancelRequestedAtToAdminJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :admin_jobs, :cancel_requested_at, :datetime
  end
end
