require "rails_helper"

RSpec.describe "Shows", :js do
  let(:venue) do
    create(
      :venue,
      slug: "madison-square-garden",
      name: "Madison Square Garden",
      city: "New York",
      state: "NY",
      latitude: 40.7505045,
      longitude: -73.9934387
    )
  end

  let(:show) do
    create(:show, :with_likes, venue:, date: "2023-08-01", duration: 120 * 60 * 1000)
  end

  let!(:set_1_tracks) do
    create_list(:track, 2, :with_likes, show:, set: 1)
  end

  let!(:set_2_tracks) do
    create_list(:track, 3, :with_likes, show:, set: 2)
  end

  let(:user) { create(:user)  }

  before do
    sign_in(user)
    visit "/2023-08-01"
  end

  it "displays the correct sidebar content" do
    within(".sidebar-content") do
      expect(page).to have_content("Aug 1, 2023")
      expect(page).to have_link("Madison Square Garden", href: "/venues/madison-square-garden")
      expect(page).to have_content("2h")
      within(".like-container") do
        expect(page).to have_content("3")
      end
    end
  end

  it "displays tracks grouped by set with correct headers" do
    within("#main-content") do
      expect(page).to have_content("Set 1")
      set_1_tracks.each do |track|
        expect(page).to have_content(track.title)
      end
      expect(page).to have_content("Set 2")
      set_2_tracks.each do |track|
        expect(page).to have_content(track.title)
      end
    end
  end

  it "displays the show context menu" do
    first(".context-dropdown .button").click

    within(".context-dropdown-content") do
      expect(page).to have_css("a.dropdown-item", text: "Share")
      expect(page).to have_css("a.dropdown-item", text: "Phish.net")
      expect(page).to have_css("a.dropdown-item", text: "Taper Notes")
      expect(page).to have_css("a.dropdown-item", text: "Madison Square Garden")
      expect(page).to have_css("a.dropdown-item", text: "New York, NY")
      expect(page).to have_css("a.dropdown-item", text: "Previous show")
      expect(page).to have_css("a.dropdown-item", text: "Next show")
    end
  end

  it "displays the track context menu for the first track" do
    first(".list-item .context-dropdown .button").click

    within(".context-dropdown-content") do
      expect(page).to have_css("a.dropdown-item", text: "Share")
      expect(page).to have_css("a.dropdown-item", text: "Download MP3")
      expect(page).to have_css("a.dropdown-item", text: "Add to Draft Playlist")
    end
  end
end
