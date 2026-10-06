require "rails_helper"

RSpec.describe "Admin publish", :js do
  let(:admin) { create(:user, :admin) }

  before do
    create(:show, date: "2025-08-01", published: false, audio_status: "missing")
    allow(Admin::ShowReadiness).to receive(:call).and_return({ ready: true, issues: [], problems: [] })
    sign_in_via_jwt(admin)
    visit "/admin/shows/2025-08-01"
    find("button.admin-publish-button:not([disabled])").click
  end

  it "enables the confirm button without typing the date" do
    expect(page).to have_css("button.admin-publish-go:not([disabled])")
  end

  it "does not ask for the date to be typed" do
    expect(page).to have_no_css("#admin-publish-confirm")
  end
end
