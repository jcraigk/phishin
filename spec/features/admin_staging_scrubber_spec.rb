require "rails_helper"

RSpec.describe "Admin staging scrubber", :js do
  let(:admin) { create(:user, :admin) }
  let(:show) { create(:show, date: "2025-08-01", published: false, audio_status: "missing") }

  before do
    create(:staged_source, show:, position: 1, offset_s: 0, duration_s: 100)
    create(:staged_track, show:, position: 1, start_s: 0, end_s: 100, original_start_s: 0, original_end_s: 100)
    sign_in_via_jwt(admin)
    visit "/admin/shows/2025-08-01"
    find("li.admin-staging-track .admin-audio-position").click
  end

  def scrubber = find("li.is-selected .waveform-scrubber")

  def click_scrubber_center
    page.driver.browser.action.move_to(scrubber.native).click.perform
  end

  it "moves the cursor to a click while paused" do
    click_scrubber_center
    expect(page).to have_css("li.is-selected .admin-audio-status", text: "50.0s")
  end

  it "moves the cursor on the first click after a marker drag released outside the waveform" do
    marker = find("li.is-selected .wf-marker", text: "end")
    page.driver.browser.action
        .move_to(marker.native).click_and_hold
        .move_by(-60, 0).move_by(0, 200).release.perform
    expect(page).to have_css("li.is-selected .admin-audio-status", text: "0.0s")

    click_scrubber_center
    expect(page).to have_css("li.is-selected .admin-audio-status", text: "50.0s")
  end
end
