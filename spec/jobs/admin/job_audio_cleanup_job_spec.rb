require "rails_helper"

RSpec.describe Admin::JobAudioCleanupJob do
  let(:admin_job) { create(:admin_job, kind: "trim_preview") }
  let(:source) { Rails.root.join("tmp/spec/cleanup_source.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    File.binwrite(source, "ID3rendered")
  end

  it "removes stored renders past the retention window" do
    path = AdminJobAudio.store(admin_job, source.to_s)
    File.utime(10.days.ago.to_time, 10.days.ago.to_time, path)
    described_class.new.perform
    expect(File.exist?(path)).to be(false)
  end

  it "leaves recent renders in place" do
    path = AdminJobAudio.store(admin_job, source.to_s)
    described_class.new.perform
    expect(File.exist?(path)).to be(true)
  end

  it "is scheduled by name that resolves to this class" do
    schedule = YAML.load_file(Rails.root.join("config/sidekiq.yml"))[:scheduler][:schedule]
    entry = schedule["admin_job_audio_cleanup"]
    expect(entry["class"].constantize).to eq(described_class)
  end
end
