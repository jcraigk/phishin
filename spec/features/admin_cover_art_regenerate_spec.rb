require "rails_helper"

RSpec.describe "Admin cover art regenerate", :js do
  let(:admin) { create(:user, :admin) }
  let(:show) { create(:show, date: "2025-08-01", published: false) }

  def attach_candidate(metadata)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("spec/fixtures/files/cover-art-large.jpg")),
      filename: "candidate.png",
      content_type: "image/png",
      metadata:
    )
    show.cover_art_candidates.attach(blob)
  end

  def open_art_tab
    sign_in_via_jwt(admin)
    visit "/admin/shows/2025-08-01"
    click_on "Art"
  end

  def regenerate(model: nil)
    find("button[aria-label='Regenerate with the same prompt']").click
    find("select[aria-label='Image model']").select(model) if model
    find("button[aria-label='Run paid regenerate']").click
    Timeout.timeout(5) { sleep 0.1 until Admin::GenerateCoverArtJob.jobs.any? }
  end

  def enqueued_prompt_and_model
    Admin::GenerateCoverArtJob.jobs.last["args"].last(2)
  end

  context "with a candidate generated from a prompt" do
    before do
      attach_candidate("prompt" => "a box turtle", "model" => "google/gemini-3.1-flash-image")
      open_art_tab
    end

    it "defaults to the candidate's model" do
      regenerate
      expect(enqueued_prompt_and_model).to eq([ "a box turtle", "google/gemini-3.1-flash-image" ])
    end

    it "uses the model chosen in the form" do
      regenerate(model: "gpt-5.4-image-2")
      expect(enqueued_prompt_and_model).to eq([ "a box turtle", "openai/gpt-5.4-image-2" ])
    end

    it "shows the chosen model on the generating card" do
      regenerate(model: "gpt-5.4-image-2")
      expect(page).to have_css(".admin-art-pending .admin-art-model", text: "gpt-5.4-image-2")
    end
  end

  context "with an edited candidate" do
    before do
      attach_candidate("prompt" => "a box turtle", "edits" => [ "make it green" ])
      open_art_tab
    end

    it "does not offer regenerate" do
      expect(page).to have_no_css("button[aria-label='Regenerate with the same prompt']")
    end
  end
end
