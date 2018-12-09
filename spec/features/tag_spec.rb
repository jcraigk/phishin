# frozen_string_literal: true
require 'rails_helper'

describe 'Tag page', :js do
  let(:tag) { create(:tag) }

  context 'shows' do
    let(:shows) { create_list(:show, 3, tags: [tag]) }

    before do
      shows.each_with_index do |show, idx|
        show.update(duration: show.duration + idx * 10)
        create_list(:like, 10 - idx, likable: show)
      end
    end

    it 'sorting' do
      visit tag_path(tag)
      click_button('Shows: 3')

      expect_show_sorting_controls(shows)
    end
  end

  context 'tracks' do
    let(:tracks) { create_list(:track, 3, tags: [tag]) }

    before do
      tracks.each_with_index do |track, idx|
        track.update(duration: track.duration + idx * 10)
        create_list(:like, 10 - idx, likable: track)
      end
    end

    it 'sorting' do
      visit tag_path(tag)
      click_button('Tracks: 3')

      expect_track_sorting_controls(tracks)
    end
  end
end
