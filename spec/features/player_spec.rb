# frozen_string_literal: true
require 'rails_helper'

describe 'Player controls', :js do
  let(:show) { create(:show, :with_tracks) }

  before { login_as create(:user) }

  it 'hovering over track title and liking' do
    visit show.date

    # First track should auto-play
    within('#player_title_container') do
      expect_content(show.tracks.first.title)
    end
    within('#player_detail') do
      expect_content(show.date_with_dots, show.venue.name, show.venue.location)
    end

    # Hover over the track title at the top of the player
    find('#player_title_container').hover

    within('#player_title_container') do
      within('.likes_large span') do
        expect_content('0')
      end
      first('.like_toggle').click
    end
    expect_content('Like acknowledged')
    within('#player_title_container .likes_large span') do
      expect_content('1')
    end

    within('#player_title_container') do
      first('.like_toggle').click
    end
    expect_content('Unlike acknowledged')
    within('#player_title_container .likes_large span') do
      expect_content('0')
    end
  end

  it 'click links below scrubber' do
    visit show.date

    within('#player_detail') do
      click_link(show.venue.location)
    end
    expect(page).to have_current_path(map_path(map_term: show.venue.location))

    within('#player_detail') do
      click_link(show.venue.name)
    end
    expect(page).to have_current_path("/#{show.venue.slug}")

    within('#player_detail') do
      click_link(show.date_with_dots)
    end
    expect(page).to have_current_path("/#{show.date}")
  end

  it 'next/previous' do
    visit show.date

    within('#player_title_container') do
      expect_content(show.tracks.first.title)
    end

    find('#control_next').click
    within('#player_title_container') do
      expect_content(show.tracks.second.title)
    end

    find('#control_next').click
    within('#player_title_container') do
      expect_content(show.tracks.third.title)
    end

    find('#control_previous').click
    within('#player_title_container') do
      expect_content(show.tracks.second.title)
    end
  end

  it 'playlist icon' do
    visit root_path

    find('#playlist_button').click
    expect(page).to have_current_path(active_playlist_path)
  end

  it 'gear icon (loop/shuffle)' do
    visit root_path

    # Click gear icon
    find('#player_menu .btn-group').click

    # Loop
    find('#loop_checkbox').set(true)
    expect_content('Playback looping enabled')
    find('#loop_checkbox').set(false)
    expect_content('Playback looping disabled')

    # Shuffle
    find('#shuffle_checkbox').set(true)
    expect_content('Playback shuffling enabled')
    find('#shuffle_checkbox').set(false)
    expect_content('Playback shuffling disabled')
  end
end
