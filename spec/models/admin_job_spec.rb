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

  it "rejects unknown statuses" do
    expect(build(:admin_job, status: "bogus")).not_to be_valid
  end
end
