require "rails_helper"

RSpec.describe Admin::EditCoverArtJob, :open_router do
  let(:show) { create(:show, date: "2024-07-19", cover_art_prompt: "a red barn") }
  let(:admin_job) { create(:admin_job, kind: "cover_art_edit", show:) }
  let(:image_bytes) { File.binread(Rails.root.join("spec/fixtures/files/cover-art-large.jpg")) }
  let(:source_blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(image_bytes), filename: "source.png", content_type: "image/png"
    )
  end
  let(:image_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: { data: [ { b64_json: Base64.strict_encode64(image_bytes) } ] }.to_json
    )
  end

  before { allow(Typhoeus).to receive(:post).and_return(image_response) }

  it "attaches the edited image as a new candidate" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(show.reload.cover_art_candidates.count).to eq(1)
  end

  it "sends the request to the images endpoint" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(Typhoeus).to have_received(:post)
      .with("https://openrouter.ai/api/v1/images", any_args).once
  end

  it "passes the source image as a data url input reference" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      body = JSON.parse(options[:body])
      expect(body["prompt"]).to eq("make it blue")
      url = body.dig("input_references", 0, "image_url", "url")
      expect(url).to start_with("data:#{source_blob.reload.content_type};base64,")
      expect(Base64.strict_decode64(url.split(",", 2).last)).to eq(image_bytes)
    end
  end

  it "edits with the requested model" do
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue", "google/gemini-3-pro-image")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(JSON.parse(options[:body])["model"]).to eq("google/gemini-3-pro-image")
    end
    expect(show.reload.cover_art_candidates.first.blob.metadata["model"]).to eq("google/gemini-3-pro-image")
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
      .with("https://openrouter.ai/api/v1/images", any_args)
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
    allow(image_response).to receive_messages(success?: false, body: "boom")
    expect { described_class.new.perform(show.id, admin_job.id, source_blob.key, "blue") }
      .to raise_error(StandardError, /Failed to generate cover art/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "reports API errors whose body is binary with non-ascii characters" do
    allow(image_response).to receive_messages(
      success?: false, body: "bad prompt: child’s".b
    )
    expect { described_class.new.perform(show.id, admin_job.id, source_blob.key, "blue") }
      .to raise_error(StandardError, /child’s/)
  end

  it "records the source prompt and edit chain on the candidate blob" do
    source_blob.update!(
      metadata: source_blob.metadata.merge("prompt" => "a red barn", "edits" => [ "bluer" ])
    )
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "add stars")
    metadata = show.reload.cover_art_candidates.first.blob.metadata
    expect(metadata["prompt"]).to eq("a red barn")
    expect(metadata["edits"]).to eq([ "bluer", "add stars" ])
  end

  it "falls back to the show's saved prompt when the source has none recorded" do
    show.update!(cover_art_prompt: "the committed snapshot")
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "add stars")
    metadata = show.reload.cover_art_candidates.first.blob.metadata
    expect(metadata["prompt"]).to eq("the committed snapshot")
    expect(metadata["edits"]).to eq([ "add stars" ])
  end

  it "records the generation cost on the candidate blob" do
    allow(image_response).to receive(:body).and_return(
      { data: [ { b64_json: Base64.strict_encode64(image_bytes) } ], usage: { cost: 0.067762 } }.to_json
    )
    described_class.new.perform(show.id, admin_job.id, source_blob.key, "make it blue")
    expect(show.reload.cover_art_candidates.first.blob.metadata["cost"]).to eq(0.0678)
  end
end
