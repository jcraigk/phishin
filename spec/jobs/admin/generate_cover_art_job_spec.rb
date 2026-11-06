require "rails_helper"

RSpec.describe Admin::GenerateCoverArtJob, :open_router do
  let(:show) { create(:show, date: "2024-07-19", cover_art_prompt: "a red barn") }
  let(:admin_job) { create(:admin_job, kind: "cover_art_generate", show:) }
  let(:image_b64) do
    Base64.strict_encode64(
      File.binread(Rails.root.join("spec/fixtures/files/cover-art-large.jpg"))
    )
  end
  let(:image_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: { data: [ { b64_json: image_b64 } ], usage: { cost: 0.0412 } }.to_json
    )
  end

  before { allow(Typhoeus).to receive(:post).and_return(image_response) }

  it "attaches a new candidate" do
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art_candidates.count).to eq(1)
  end

  it "requests generation from the image API exactly once" do
    described_class.new.perform(show.id, admin_job.id)
    expect(Typhoeus).to have_received(:post)
      .with("https://openrouter.ai/api/v1/images", any_args).once
  end

  it "generates with the default model when none is given" do
    described_class.new.perform(show.id, admin_job.id)
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(JSON.parse(options[:body])["model"]).to eq(CoverArtImageService.default_model)
    end
  end

  it "generates with the requested model" do
    described_class.new.perform(show.id, admin_job.id, nil, "openai/gpt-image-2.6-sunburst")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(JSON.parse(options[:body])["model"]).to eq("openai/gpt-image-2.6-sunburst")
    end
  end

  it "sends a quality variant as the base model plus that quality" do
    described_class.new.perform(show.id, admin_job.id, nil, "openai/gpt-image-2.6-sunburst:xhigh")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(JSON.parse(options[:body])).to include("model" => "openai/gpt-image-2.6-sunburst", "quality" => "xhigh")
    end
  end

  it "records a quality variant as the candidate model" do
    described_class.new.perform(show.id, admin_job.id, nil, "openai/gpt-image-2.6-sunburst:max")
    expect(show.reload.cover_art_candidates.first.blob.metadata["model"]).to eq("openai/gpt-image-2.6-sunburst:max")
  end

  it "records the model and cost on the candidate blob" do
    described_class.new.perform(show.id, admin_job.id, nil, "openai/gpt-image-2.6-sunburst")
    metadata = show.reload.cover_art_candidates.first.blob.metadata
    expect(metadata).to include("model" => "openai/gpt-image-2.6-sunburst", "cost" => 0.0412)
  end

  it "sends the prompt override when one is given" do
    described_class.new.perform(show.id, admin_job.id, "a blue barn")
    expect(Typhoeus).to have_received(:post) do |_url, options|
      expect(JSON.parse(options[:body])["prompt"]).to eq("a blue barn")
    end
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
    allow(image_response).to receive_messages(success?: false, body: "boom")
    expect { described_class.new.perform(show.id, admin_job.id) }
      .to raise_error(StandardError, /Failed to generate cover art/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "never retries on its own, so a failed paid AI call is not silently rerun" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(0)
  end
end
