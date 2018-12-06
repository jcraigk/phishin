# frozen_string_literal: true
require 'rails_helper'

feature 'Track Context Menues', :js do
  given(:show) { create(:show, :with_tracks) }
  given(:track) { show.tracks.first }

  scenario 'add to playlist, this song' do
    visit show.date

    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      expect_content('Play', 'Add to playlist', 'Share', 'Download MP3', 'This song...')
    end

    click_link('Add to playlist')
    expect_content('Track added to playlist')

    click_link('This song...')
    expect(page).to have_current_path("/#{show.tracks.first.songs.first.slug}")
  end

  scenario 'share' do
    visit show.date

    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      click_link('Share')
    end
    expect_content('Copypasta...')
    first('.close').click
  end
end
