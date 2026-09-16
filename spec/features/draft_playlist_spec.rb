require "rails_helper"

RSpec.describe "Draft Playlist", :js do
  let(:user) { create(:user) }
  let!(:show) { create(:show, date: "1995-12-31", audio_status: "complete") }

  before do
    create(:track, show:, title: "Wilson", position: 1)
    create(:track, show:, title: "Reba", position: 2)
    create(:track, show:, title: "Weekapaug", position: 3)
sign_in_via_jwt(user)
  end


  def draft_row(title)
    all(".draft-track-list .list-item").find { |row| row.find(".leftside-primary").text.include?(title) }
  end

  def open_show_in_builder
    visit "/draft-playlist"
    within(".playlist-builder") do
      find(".builder-year", text: "1995").click
      find(".builder-show-row", text: "Dec 31, 1995").click
      expect(page).to have_css(".builder-track-row")
    end
  end

  def add_tracks_from_builder(titles)
    open_show_in_builder
    within(".playlist-builder") do
      titles.each do |title|
        within(".builder-track-row", text: title) { click_on "Add" }
      end
    end
  end

  it "builds and saves a playlist from the date browser" do
    add_tracks_from_builder(%w[Wilson Reba])

    within("#sidebar") do
      fill_in "playlist-name", with: "New Years Jams"
      click_on "Save"
    end

    expect(page).to have_text("Playlist saved successfully")
    playlist = Playlist.find_by(name: "New Years Jams")
    expect(playlist.tracks.order("playlist_tracks.position").map(&:title)).to eq(%w[Wilson Reba])
  end

  it "shows added tracks in the draft list and lets the author remove them" do
    add_tracks_from_builder(%w[Wilson Reba])

    within(".draft-track-list") do
      expect(page).to have_css(".list-item", count: 2)
      within(draft_row("Wilson")) { find(".draft-remove").click }
      expect(page).to have_css(".list-item", count: 1)
      expect(page).to have_no_text("Wilson")
    end
  end

  it "repositions a track with the row select" do
    add_tracks_from_builder(%w[Wilson Reba Weekapaug])

    within(draft_row("Weekapaug")) do
      select "1. Wilson", from: "reposition"
    end

    titles = all(".draft-track-list .list-item .leftside-primary").map(&:text)
    expect(titles.first).to include("Weekapaug")
  end

  it "keeps the draft after a reload" do
    add_tracks_from_builder(%w[Wilson Reba])
    within("#sidebar") { fill_in "playlist-name", with: "Sticky Draft" }

    visit "/draft-playlist"

    expect(page).to have_css(".draft-track-list .list-item", count: 2)
    expect(find_field("playlist-name").value).to eq("Sticky Draft")
  end

  it "jumps straight to a show from the date input" do
    visit "/draft-playlist"
    within(".playlist-builder") do
      find_by_id("builder-date").send_keys("12311995")
      expect(page).to have_css(".builder-track-row", text: "Reba")
    end
  end
end
