# frozen_string_literal: true
require 'rails_helper'

feature 'Tag page', :js do
  given(:tag) { create(:tag) }

  context 'shows' do
    given(:shows) { create_list(:show, 3, tags: [tag]) }

    before do
      shows.each_with_index do |show, idx|
        show.update(duration: show.duration + idx * 10)
        create_list(:like, 10 - idx, likable: show)
      end
    end

    scenario 'sorting' do
      visit tag_path(tag)
      click_button('Shows: 3')

      expect_show_sorting_controls(shows)
    end
  end

  context 'tracks' do
    given(:tracks) { create_list(:track, 3, tags: [tag]) }

    before do
      tracks.each_with_index do |track, idx|
        track.update(duration: track.duration + idx * 10)
        create_list(:like, 10 - idx, likable: track)
      end
    end

    scenario 'sorting' do
      visit tag_path(tag)
      click_button('Tracks: 3')

      expect_track_sorting_controls(tracks)
    end
  end
end
