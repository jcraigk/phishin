require "rails_helper"

# CoverArtPromptService calls the paid chat completions endpoint through
# Typhoeus.post, so it is stubbed in every example that lets the real service
# run, and replaced with a double everywhere else.
RSpec.describe Admin::RegenerateCoverArtPromptJob, :openai do
  let(:venue) { create(:venue) }
  let(:show) { create(:show, date: "2024-07-19", venue:) }
  let(:admin_job) { create(:admin_job, kind: "cover_art_prompt", show:) }
  let(:categories) do
    CoverArtPromptService::CATEGORIES.index_with { |_c| [ "a pigeon" ] }
  end
  let(:chat_response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: {
        choices: [ { message: { content: categories.to_json } } ]
      }.to_json
    )
  end

  before { allow(Typhoeus).to receive(:post).and_return(chat_response) }

  it "writes a prompt onto the show" do
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art_prompt).to be_present
  end

  it "writes a hue and style from the known lists" do
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload).to have_attributes(
      cover_art_hue: be_in(CoverArtPromptService::HUES),
      cover_art_style: be_in(CoverArtPromptService::STYLES)
    )
  end

  it "records the resulting prompt on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.payload["prompt"]).to eq(show.reload.cover_art_prompt)
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
