require "rails_helper"

RSpec.describe "Songs", :js do
  let!(:original_song) do
    create(
      :song,
      title: "Original Song",
      original: true,
      tracks_count: 10,
      slug: "original-song"
    )
  end
  let!(:cover_song) do
    create(
      :song,
      title: "Cover Song",
      original: false,
      tracks_count: 5,
      slug: "cover-song"
    )
  end

  before do
    visit "/songs"
  end

  it "displays the sidebar with sorting and filtering options" do
    expect(page).to have_css(".sidebar-title", text: "Songs")
    expect(page).to have_css(".sidebar-subtitle", text: "2 total")
    expect(page).to have_css("select#sort")
    expect(page).to have_css("input#search")
    expect(page).to have_button("Search")
  end

  it "displays the list of songs with their details" do
    select "Sort by Tracks Count (High to Low)", from: "sort"

    within first(".list-item", text: "Original Song") do
      expect(page).to have_css(".leftside-primary", text: "Original Song")
      expect(page).to have_css(".leftside-secondary", text: "Original")
      expect(page).to have_css(".rightside-group", text: "10 tracks")
    end

    within first(".list-item", text: "Cover Song") do
      expect(page).to have_css(".leftside-primary", text: "Cover Song")
      expect(page).to have_css(".leftside-secondary", text: "Cover")
      expect(page).to have_css(".rightside-group", text: "5 tracks")
    end
  end

  it "submits search and navigates to the search results page" do
    fill_in "search", with: "Original"
    click_button "Search"

    expect(page).to have_current_path("/search?term=Original&scope=songs")
  end
end
