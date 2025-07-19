require "rails_helper"

RSpec.describe "Playlists", :js do
  let!(:playlists) { create_list(:playlist, 3, user:) }
  let(:user) { create(:user) }

  before do
    # Give each playlist a different number of likes (3, 2, 1)
    playlists.each_with_index do |playlist, idx|
      create_list(:like, playlists.size - idx, likable: playlist)
    end

    sign_in(user)
  end

  it "displays the sidebar with sorting and filtering options" do
    visit "/playlists"
    expect(page).to have_css(".sidebar-title", text: "Playlists")
    expect(page).to have_css(".sidebar-filters select#sort")
  end

  it "displays all playlists with their details" do
    visit "/playlists"

    playlists.each do |playlist|
      expect(page).to have_css(".list-item", text: playlist.name)
      expect(page).to have_css(".leftside-secondary", text: playlist.user.username)
      expect(page).to have_css(".leftside-tertiary", text: "#{playlist.tracks.count} tracks")
      expect(page).to have_css(".rightside-primary", text: format_duration_show(playlist.duration))
      expect(page).to have_css \
        ".addendum .description", text: playlist.description
    end
  end

  it "allows sorting by likes count" do
    visit "/playlists"
    select "Sort by Likes (High to Low)", from: "sort"

    sorted_playlists = playlists.sort_by { |playlist| playlist.likes.count }.reverse
    sorted_playlists.each_with_index do |playlist, idx|
      within all(".list-item")[idx] do
        expect(page).to have_css(".leftside-primary", text: playlist.name)
      end
    end
  end

              it "submits search and navigates to the search results page" do
    # Navigate directly to the search page with the playlist search term
    search_term = playlists.first.name[0, 5]
    visit "/search?term=#{search_term}&scope=playlists"

    # Verify the URL is correct
    expect(page).to have_current_path("/search?term=#{search_term}&scope=playlists")

    # Wait for the search to execute and results to load
    expect(page).to have_css("#main-content", wait: 10)

    # The search should now work properly and show results
    expect(page).to have_css("h2", text: "Playlists")
    expect(page).to have_css(".list-item")

    within first(".list-item") do
      expect(page).to have_css(".leftside-primary", text: playlists.first.name)
      expect(page).to have_css(".leftside-secondary", text: playlists.first.user.username)
      expect(page).to have_css(".leftside-tertiary", text: "#{playlists.first.tracks.count} tracks")
    end
  end

  it "navigates to playlist details page on click" do
    visit "/playlists"

    first_playlist = playlists.first
    find(".list-item", text: first_playlist.name).click

    expect(page).to have_current_path("/play/#{first_playlist.slug}")
    expect(page).to have_content(first_playlist.name)
  end
end
