require "rails_helper"

RSpec.describe "Static pages", :js do
  before { create(:show, date: "2023-08-01") }

  it "navigates from the homepage to the FAQ" do
    visit "/"

    within("#navbar") do
      click_on("INFO")
      click_on("FAQ")
    end

    expect(page).to have_current_path("/faq")
    expect(page).to have_css("h1", text: "Frequently Asked Questions")
  end

  it "loads the API docs directly" do
    visit "/api-docs"

    expect(page).to have_css("h1", text: "API Documentation")
  end
end
