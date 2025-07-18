require "rails_helper"

RSpec.describe "Venues", :js do
  let(:venue1) do
    create(
      :venue,
      name: "Awesome Venue",
      city: "New York",
      shows_count: 15,
      shows_with_audio_count: 15,
      slug: "awesome-venue"
    )
  end
  let(:venue2) do
    create(
      :venue,
      name: "Brilliant Venue",
      city: "Los Angeles",
      shows_count: 5,
      shows_with_audio_count: 5,
      slug: "brilliant-venue"
    )
  end

  before do
    venue1
    venue2
    visit "/venues"
  end

  it "displays the sidebar with sorting and filtering options" do
    expect(page).to have_css(".sidebar-title", text: "Venues")
    expect(page).to have_css(".sidebar-subtitle", text: "2 total")
    expect(page).to have_select("sort")
    expect(page).to have_select("first-char-filter")
    expect(page).to have_field("search")
    expect(page).to have_button("Search")
  end

  it "displays the list of venues with their details" do
    select "Sort by Shows Count (High to Low)", from: "sort"

    within first(".list-item", text: "Awesome Venue") do
      expect(page).to have_css(".leftside-primary", text: "Awesome Venue")
      expect(page).to have_css(".leftside-secondary", text: "New York")
      expect(page).to have_css(".rightside-group", text: "15 shows")
    end

    within first(".list-item", text: "Brilliant Venue") do
      expect(page).to have_css(".leftside-primary", text: "Brilliant Venue")
      expect(page).to have_css(".leftside-secondary", text: "Los Angeles")
      expect(page).to have_css(".rightside-group", text: "5 shows")
    end
  end

  it "submits search and navigates to the search results page" do
    fill_in "search", with: "Awesome"
    click_on "Search"

    expect(page).to have_current_path("/search?term=Awesome&scope=venues")
  end
end
