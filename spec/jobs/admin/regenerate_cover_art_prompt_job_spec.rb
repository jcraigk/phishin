require "rails_helper"

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

  it "does not change the saved prompt on the show" do
    show.update!(cover_art_prompt: "the committed snapshot")
    described_class.new.perform(show.id, admin_job.id)
    expect(show.reload.cover_art_prompt).to eq("the committed snapshot")
  end

  it "records a suggested prompt on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.payload["prompt"]).to include("a pigeon")
  end

  it "records a hue and style from the known lists on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.payload["hue"]).to be_in(CoverArtPromptService::HUES)
    expect(admin_job.reload.payload["style"]).to be_in(CoverArtPromptService::STYLES)
  end

  it "records the category suggestions on the job payload" do
    described_class.new.perform(show.id, admin_job.id)
    suggestions = admin_job.reload.payload["suggestions"]
    expect(suggestions.keys).to match_array(CoverArtPromptService::CATEGORIES)
    expect(suggestions["animals"]).to eq([ "a pigeon" ])
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
