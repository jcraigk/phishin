require "rails_helper"

RSpec.describe Admin::EditCoverArtJob, :openai do
  let(:show) { create(:show, date: "2024-07-19", cover_art_prompt: "a red barn") }
  let(:admin_job) { create(:admin_job, kind: "cover_art_edit", show:) }
  let(:image_bytes) { File.binread(Rails.root.join("spec/fixtures/files/cover-art-large.jpg")) }
  let(:source_blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(image_bytes), filename: "source.png", content_type: "image/png"
    )
  end
  let(:openai_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: { data: [ { b64_json: Base64.strict_encode64(image_bytes) } ] }.to_json
    )
  end

  before { allow(Typhoeus).to receive(:post).and_return(openai_response) }

  it "attaches the edited image as a new candidate" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(show.reload.cover_art_candidates.count).to eq(1)
  end

  it "sends the request to the image edit endpoint" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(Typhoeus).to have_received(:post)
      .with("https://api.openai.com/v1/images/edits", any_args).once
  end

  it "declares an image mimetype for the multipart image part" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(options[:headers]["Content-Type"]).to match(%r{multipart/form-data; boundary=})
      expect(options[:body]).to include("name=\"image\"")
      expect(options[:body]).to include("Content-Type: #{source_blob.reload.content_type}")
      expect(source_blob.reload.content_type).to start_with("image/")
    end
  end

  it "keeps the source blob attached to nothing it did not own" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(ActiveStorage::Blob.exists?(source_blob.id)).to be(true)
  end

  it "produces a candidate distinct from the source blob" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(show.reload.cover_art_candidates.first.blob).not_to eq(source_blob)
  end

  it "edits even when the show is linked to a parent show" do
    parent = create(:show, date: "2024-07-18")
    show.update!(cover_art_parent_show_id: parent.id)
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(Typhoeus).to have_received(:post)
      .with("https://api.openai.com/v1/images/edits", any_args)
  end

  it "records the new candidate on the job payload" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(admin_job.reload.payload["blob_key"])
      .to eq(show.reload.cover_art_candidates.first.blob.key)
  end

  it "completes the admin job" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(admin_job.reload.status).to eq("done")
  end

  it "fails the admin job when the source blob is unknown" do
    expect { described_class.new.perform(show.id, admin_job.id, "nope", "make it blue") }
      .to raise_error(ActiveRecord::RecordNotFound)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "fails the admin job when the image API errors" do
    allow(openai_response).to receive_messages(success?: false, body: "boom")
    expect { described_class.new.perform(show.id, admin_job.id, source_blob.key, "blue") }
      .to raise_error(StandardError, /Failed to generate cover art/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "reports API errors whose body is binary with non-ascii characters" do
    allow(openai_response).to receive_messages(
      success?: false, body: "bad prompt: child’s".b
    )
    expect { described_class.new.perform(show.id, admin_job.id, source_blob.key, "blue") }
      .to raise_error(StandardError, /child’s/)
  end

  it "records the generation cost on the candidate blob" do
    allow(openai_response).to receive(:body).and_return(
      {
        data: [ { b64_json: Base64.strict_encode64(image_bytes) } ],
        usage: {
          input_tokens: 400,
          input_tokens_details: { text_tokens: 100, image_tokens: 300 },
          output_tokens: 6000
        }
      }.to_json
    )
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    cost = show.reload.cover_art_candidates.first.blob.metadata["cost"]
    expect(cost).to be_within(0.0001).of(0.1829)
  end
end
