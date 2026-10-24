require "rails_helper"

RSpec.describe AdminJobAudio do
  let(:admin_job) { create(:admin_job, kind: "trim_preview") }
  let(:source) { Rails.root.join("tmp/spec/admin_job_audio_source.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    File.binwrite(source, "ID3rendered")
  end

  describe ".dir" do
    it "lives on the shared content volume in Docker so the web container can serve worker renders" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("IN_DOCKER").and_return("true")
      expect(described_class.dir).to eq(Pathname.new("/content/admin_job_audio"))
    end

    it "lives under tmp outside Docker" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("IN_DOCKER").and_return(nil)
      expect(described_class.dir).to eq(Rails.root.join("tmp/admin_job_audio"))
    end
  end

  describe ".store" do
    it "copies the render to a job-scoped path" do
      path = described_class.store(admin_job, source.to_s)
      expect(path).to eq(described_class.dir.join("#{admin_job.id}_0.mp3").to_s)
      expect(File.binread(path)).to eq("ID3rendered")
    end

    it "keeps the stored copy when the source is overwritten" do
      path = described_class.store(admin_job, source.to_s)
      File.binwrite(source, "ID3different")
      expect(File.binread(path)).to eq("ID3rendered")
    end

    it "stores additional renders under their own index" do
      described_class.store(admin_job, source.to_s)
      second = described_class.store(admin_job, source.to_s, index: 1)
      expect(second).to end_with("#{admin_job.id}_1.mp3")
    end

    it "raises when the render is missing" do
      expect { described_class.store(admin_job, "/nope/missing.mp3") }
        .to raise_error(described_class::MissingRenderError)
    end

    it "raises when no path is given" do
      expect { described_class.store(admin_job, nil) }
        .to raise_error(described_class::MissingRenderError)
    end
  end

  describe ".prune" do
    it "deletes renders older than the retention window" do
      path = described_class.store(admin_job, source.to_s)
      File.utime(10.days.ago.to_time, 10.days.ago.to_time, path)
      expect { described_class.prune }.to change { File.exist?(path) }.to(false)
    end

    it "keeps renders inside the retention window" do
      path = described_class.store(admin_job, source.to_s)
      described_class.prune
      expect(File.exist?(path)).to be(true)
    end
  end
end
