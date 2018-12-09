# frozen_string_literal: true
require 'rails_helper'

feature 'Song page', :js do
  given(:song) { create(:song) }
  given(:tracks) { create_list(:track, 3, songs: [song]) }

  before do
    tracks.each_with_index do |track, idx|
      track.update(duration: track.duration + idx * 10)
      create_list(:like, 10 - idx, likable: track)
    end
  end

  scenario 'sorting' do
    visit "/#{song.slug}"

    expect_track_sorting_controls(tracks)
  end
end
