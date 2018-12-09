# frozen_string_literal: true
require 'rails_helper'

feature 'My Tracks', :js do
  given(:user) { create(:user) }
  given(:tracks) { create_list(:track, 3) }

  before do
    tracks.each_with_index do |track, idx|
      create(:like, likable: track, user: user)
      create_list(:like, 10 - idx, likable: track)
      track.update(duration: track.duration + idx * 10)
    end

    login_as(user)
  end

  scenario 'click My Tracks, display/sorting of tracks' do
    visit root_path

    find('#user_controls').click
    click_link('My Track')

    expect(page).to have_current_path(my_tracks_path)

    expect_track_sorting_controls(tracks)
  end
end
