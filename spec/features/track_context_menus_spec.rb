# frozen_string_literal: true
require 'rails_helper'

describe 'Track Context Menues', :js do
  let(:show) { create(:show, :with_tracks) }
  let(:track) { show.tracks.first }

  before do
    track.songs << create(:song)
  end

  it 'add to playlist, this song' do
    visit show.date

    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      expect_content('Play', 'Add to playlist', 'Share', 'Download MP3', track.songs.first.title, track.songs.second.title)
    end

    click_link('Add to playlist')
    expect_content('Track added to playlist')

    click_link(track.songs.first.title)
    expect(page).to have_current_path("/#{show.tracks.first.songs.first.slug}")
  end

  it 'share' do
    visit show.date

    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      click_link('Share')
    end
    expect_content('Link copied to clipboard')
  end
end
