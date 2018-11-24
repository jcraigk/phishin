# frozen_string_literal: true
require 'rails_helper'

feature 'Show', :js do
  given(:show) { create(:show, :with_tracks, :with_likes, :with_tags) }
  given(:track) { show.tracks.first }

  before do
    track.tags << create(:tag)
  end

  scenario 'visit show page' do
    visit show.date

    within('#title_box') do
      expect_content(
        show.venue.name,
        'Taper Notes',
        show.tags.first.name,
        'Next Show',
        'Previous Show'
      )
    end

    # Main content
    within('#content_box') do
      expect_content('Set 1')
      expect_content(*show.tracks.map(&:title))
    end

    track_items = page.all('.playable_track')
    expect(track_items.count).to eq(show.tracks.count)

    # Show context dropdown
    first('.show-context-dropdown').click
    within('.show-context-dropdown') do
      expect_content('Add to playlist', 'Share', 'Lookup at phish.net')
    end

    # Track context dropdown
    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      expect_content('Play', 'Add to playlist', 'Share', 'Download MP3', 'This song...')
    end
  end
end
