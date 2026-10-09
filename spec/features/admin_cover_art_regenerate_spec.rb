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

  context "with a candidate generated from a prompt" do
    before do
      attach_candidate("prompt" => "a box turtle", "model" => "google/gemini-3.1-flash-image")
      open_art_tab
      find("button[aria-label='Regenerate with the same prompt']").click
      Timeout.timeout(5) { sleep 0.1 until Admin::GenerateCoverArtJob.jobs.any? }
    end

    it "enqueues a generate job with the candidate's prompt and model" do
      expect(Admin::GenerateCoverArtJob.jobs.last["args"].last(2))
        .to eq([ "a box turtle", "google/gemini-3.1-flash-image" ])
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
