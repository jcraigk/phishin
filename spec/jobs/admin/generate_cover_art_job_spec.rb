require "rails_helper"

RSpec.describe Admin::GenerateCoverArtJob, :openai do
  let(:show) { create(:show, date: "2024-07-19", cover_art_prompt: "a red barn") }
  let(:admin_job) { create(:admin_job, kind: "cover_art_generate", show:) }
  let(:image_b64) do
    Base64.strict_encode64(
      File.binread(Rails.root.join("spec/fixtures/files/cover-art-large.jpg"))
    )
  end
  let(:openai_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: { data: [ { b64_json: image_b64 } ] }.to_json
    )
  end

  before { allow(Typhoeus).to receive(:post).and_return(openai_response) }

  it "attaches a new candidate" do
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art_candidates.count).to eq(1)
  end

  it "requests generation from the image API exactly once" do
    described_class.new.perform(show.id, admin_job.id)
    expect(Typhoeus).to have_received(:post)
      .with("https://api.openai.com/v1/images/generations", any_args).once
  end

  it "leaves the show's existing cover art untouched" do
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art).not_to be_attached
  end

  it "records the new candidate on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.payload["blob_key"])
      .to eq(show.reload.cover_art_candidates.first.blob.key)
  end

  it "completes the admin job" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.status).to eq("done")
  end

  it "fails the admin job when the image API errors" do
    allow(openai_response).to receive_messages(success?: false, body: "boom")
    expect { described_class.new.perform(show.id, admin_job.id) }
      .to raise_error(StandardError, /Failed to generate cover art/)
    expect(admin_job.reload.status).to eq("failed")
  end

  describe "when the show is linked to a parent show" do
    let(:parent) { create(:show, date: "2024-07-18") }

    before do
      parent.cover_art.attach(
        io: StringIO.new("png bytes"), filename: "parent.png", content_type: "image/png"
      )
      show.update!(cover_art_parent_show_id: parent.id)
    end

    it "reuses the parent's cover art blob as the candidate" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.cover_art_candidates.first.blob).to eq(parent.cover_art.blob)
    end

    it "does not call the image API" do
      described_class.new.perform(show.id, admin_job.id)
      expect(Typhoeus).not_to have_received(:post)
    end

    it "fails when the parent has no cover art" do
      parent.cover_art.attachment.destroy
      expect { described_class.new.perform(show.id, admin_job.id) }
        .to raise_error(StandardError, /Parent show has no cover art/)
      expect(admin_job.reload.status).to eq("failed")
    end
  end
end
