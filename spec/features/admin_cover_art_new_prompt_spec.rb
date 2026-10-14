require "rails_helper"

RSpec.describe "Admin cover art new prompt", :js do
  let(:admin) { create(:user, :admin) }
  let(:show) { create(:show, date: "2025-08-01", published: false) }
  let(:prompts) { [ "a box turtle", "a heron at dusk", "a lighthouse" ] }

  def open_new_prompt
    find("button[aria-label='New image from a prompt']").click
  end

  def generate_prompts
    click_on "Generate prompt"
    job = Timeout.timeout(5) do
      sleep 0.1 until AdminJob.exists?(kind: "cover_art_prompt")
      AdminJob.find_by(kind: "cover_art_prompt")
    end
    job.update!(status: "done", payload: { "prompt" => prompts.first, "prompts" => prompts, "hue" => "teal" })
  end

  before do
    show
    sign_in_via_jwt(admin)
    visit "/admin/shows/2025-08-01"
    click_on "Art"
  end

  it "keeps the generated prompts after submitting one" do
    open_new_prompt
    generate_prompts
    within(".admin-art-prompt-options") { click_button "a heron at dusk" }
    click_on "Submit"
    Timeout.timeout(5) { sleep 0.1 until Admin::GenerateCoverArtJob.jobs.any? }

    open_new_prompt
    expect(page).to have_css(".admin-art-prompt-options button", count: 3)
  end
end
