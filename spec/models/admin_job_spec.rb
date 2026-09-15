require "rails_helper"

RSpec.describe AdminJob do
  it "marks done after a successful run" do
    job = create(:admin_job)
    job.run! { |j| j.update!(progress: 50) }
    expect(job.reload.status).to eq("done")
    expect(job.progress).to eq(100)
  end

  it "marks failed and re-raises on error" do
    job = create(:admin_job)
    expect { job.run! { raise "boom" } }.to raise_error("boom")
    expect(job.reload.status).to eq("failed")
    expect(job.message).to eq("boom")
  end

  it "marks cancelled and re-raises when the block sees a cancel request" do
    job = create(:admin_job, kind: "ingest")
    expect {
      job.run! { |j| j.request_cancel!; j.check_cancel! }
    }.to raise_error(AdminJob::Cancelled)
    expect(job.reload.status).to eq("cancelled")
  end

  it "is cancellable only while an ingest is active and not yet asked to stop" do
    expect(create(:admin_job, kind: "ingest", status: "running")).to be_cancellable
    expect(create(:admin_job, kind: "ingest", status: "done")).not_to be_cancellable
    expect(create(:admin_job, kind: "publish", status: "running")).not_to be_cancellable
    asked = create(:admin_job, kind: "ingest", status: "running", cancel_requested_at: Time.current)
    expect(asked).not_to be_cancellable
  end

  it "rejects unknown statuses" do
    expect(build(:admin_job, status: "bogus")).not_to be_valid
  end
end
