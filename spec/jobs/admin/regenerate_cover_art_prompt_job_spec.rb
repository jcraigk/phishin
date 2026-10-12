require "rails_helper"

RSpec.describe Admin::RegenerateCoverArtPromptJob, :open_router do
  let(:venue) { create(:venue) }
  let(:show) { create(:show, date: "2024-07-19", venue:) }
  let(:admin_job) { create(:admin_job, kind: "cover_art_prompt", show:) }
  let(:prompts) { [ "A pigeon on a fire escape", "A neon diner sign in fog", "Rain on a pier", "A moth at a streetlight" ] }
  let(:chat_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: { choices: [ { message: { content: { prompts: }.to_json } } ] }.to_json
    )
  end

  before do
    allow(Typhoeus).to receive_messages(
      post: chat_response, get: instance_double(Typhoeus::Response, success?: false)
    )
  end

  it "does not change the saved prompt on the show" do
    show.update!(cover_art_prompt: "the committed snapshot")
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art_prompt).to eq("the committed snapshot")
  end

  it "records a suggested prompt on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.payload["prompt"]).to include("A pigeon")
  end

  it "records every candidate prompt with its hue and styles on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    payload = admin_job.reload.payload
    expect(payload["prompts"].size).to eq(CoverArtPromptService::CANDIDATES)
    expect(payload["prompts"].first).to start_with("A pigeon on a fire escape")
    expect(CoverArtVariety::HUES).to have_key(payload["hue"])
    expect(payload["styles"].size).to eq(CoverArtPromptService::CANDIDATES)
  end

  it "asks the chosen model for the prompts" do
    allow(CoverArtPromptService).to receive(:call).and_call_original
    described_class.new.perform(show.id, admin_job.id, "anthropic/claude-opus-5")
    expect(CoverArtPromptService).to have_received(:call).with(show, dry_run: true, model: "anthropic/claude-opus-5")
  end

  it "completes the admin job" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.status).to eq("done")
  end

  it "fails the admin job when the service raises" do
    allow(CoverArtPromptService).to receive(:call).and_raise(StandardError, "prompt boom")
    expect { described_class.new.perform(show.id, admin_job.id) }
      .to raise_error(StandardError, "prompt boom")
    expect(admin_job.reload).to have_attributes(status: "failed", message: "prompt boom")
  end
end
