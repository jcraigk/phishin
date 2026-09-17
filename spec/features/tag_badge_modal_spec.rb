require "rails_helper"

RSpec.describe "Tag badge modal", :js do
  let(:tag) { create(:tag, name: "Tease", description: "A tease of another song") }
  let(:show) { create(:show, date: "2023-08-01") }

  before { create(:track_tag, track: create(:track, show:), tag:, notes: "Bathtub Gin tease") }

  it "opens the tag details modal when the badge is clicked" do
    visit "/2023-08-01"

    find(".leftside-tertiary .tag-badge", text: "Tease").click

    within(".modal-content") do
      expect(page).to have_css(".tags-container .tag-badge", text: "Tease")
      expect(page).to have_text("Bathtub Gin tease")
    end
  end

  it "opens the tag details modal from the track menu on a touch device" do
    emulate_touch_device

    visit "/2023-08-01"
    first(".list-item .context-dropdown .button").click
    within(".context-dropdown-content") { find(".tag-badge", text: "Tease").click }

    within(".modal-content") do
      expect(page).to have_text("Bathtub Gin tease")
    end
    expect(page).to have_no_css(".play-pause-btn.playing")
  ensure
    reset_touch_emulation
  end
end
