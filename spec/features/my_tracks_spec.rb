require "rails_helper"

RSpec.describe "My Tracks", :js do
  let(:user) { create(:user) }
  let(:venue) { create(:venue) }
  let(:show) { create(:show, venue:) }
  let(:tracks) { create_list(:track, 3, show:) }

  before do
    tracks.each_with_index do |track, idx|
      create(:like, likable: track, user:)
      track.update(duration: track.duration + ((idx + 1) * 60)) # Increment duration for sorting
      create_list(:like, (tracks.size - idx), likable: track) # Increment likes for sorting
    end

    sign_in(user)
  end

  it "displays and sorts tracks by default" do
    visit "/my-tracks"
    expect(page).to have_current_path("/my-tracks")
    expect(page).to have_content("My Tracks")
    tracks.sort_by { _1.show.date }.reverse.each_with_index do |track, idx|
      expect(page).to have_content(track.show.date.strftime("%b %-d, %Y"))
      expect(page).to have_content(track.title)
    end
  end

  it "allows sorting by likes count" do
    visit "/my-tracks"
    select "Sort by Likes (High to Low)", from: "sort"
    sorted_tracks = tracks.sort_by { _1.likes.count }.reverse
    sorted_tracks.each_with_index do |track, idx|
      expect(page).to have_content(track.show.date.strftime("%b %-d, %Y"))
      expect(page).to have_content(track.title)
    end
  end

  it "allows sorting by duration" do
    visit "/my-tracks"
    select "Sort by Duration (Longest First)", from: "sort"
    sorted_tracks = tracks.sort_by(&:duration).reverse
    sorted_tracks.each_with_index do |track, idx|
      expect(page).to have_content(track.show.date.strftime("%b %-d, %Y"))
      expect(page).to have_content(track.title)
    end
  end

  context "with more tracks" do
    let(:tracks) { create_list(:track, 13, show:) }

    it "paginates tracks" do
      visit "/my-tracks"
      expect(page).to have_selector(".pagination")
      find(".pagination li", text: "2").click
      expect(page).to have_current_path(/\/my-tracks.*page=2/)
      expect(page).to have_selector(".list-item", count: 3)
    end
  end
end
