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
      expect_content(show.venue.name, 'Taper Notes', show.tags.first.name, 'Next Show', 'Previous Show')
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

  context 'liking' do
    scenario 'when not logged in' do
      visit show.date
      within('#title_box') do
        first('.like_toggle').click
      end
      expect_content('You must be signed in to submit Likes')
    end

    context 'when logged in' do
      before do
        login_as(create(:user))
        visit show.date
      end

      scenario 'liking/unliking the show' do
        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')
        # TODO: ensure number increments

        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Unlike acknowledged')
        # TODO: ensure number decrements

        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')

        visit my_shows_path
        expect_content(show.venue.name) # TODO: look for date (matcher?)
      end

      scenario 'liking/unliking a track' do
        within('#content_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')
        # TODO: ensure number increments

        visit my_tracks_path
        expect_content(show.tracks.first.title)
      end
    end
  end
end
