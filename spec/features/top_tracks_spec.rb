require "rails_helper"

RSpec.describe "Top Tracks", :js do
  let!(:tracks) { create_list(:track, 3) }

  before do
    tracks.each_with_index do |track, idx|
      create_list(:like, tracks.size - idx, likable: track)
    end
  end

  it "displays the list of top tracks with numbering and links" do
    visit "/top-tracks"

    expect(page).to have_css(".sidebar-title", text: "Top 46 Tracks")

    tracks.sort_by { |track| track.likes_count }.reverse.each_with_index do |track, idx|
      within all(".list-item")[idx] do
        expect(page).to have_css(".leftside-primary", text: track.title)
        within(".like-container") do
          expect(page).to have_content(track.likes_count)
        end
        expect(page).to have_css(".leftside-numbering", text: "##{idx + 1}")
      end
    end
  end
end
