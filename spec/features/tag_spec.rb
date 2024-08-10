require 'rails_helper'

describe 'Tag page', :js do
  let(:tag) { create(:tag) }

  context 'with shows' do
    let(:shows) { create_list(:show, 3, tags: [ tag ]) }

    before do
      shows.each_with_index do |show, idx|
        show.update(duration: show.duration + (idx * 10))
        create_list(:like, 10 - idx, likable: show)
      end
    end

    it 'sorting' do
      visit tag_path(tag)
      click_button('Shows: 3') # rubocop:disable Capybara/ClickLinkOrButtonStyle

      expect_show_sorting_controls(shows)
    end
  end

  context 'with tracks' do
    let(:tracks) { create_list(:track, 3, tags: [ tag ]) }

    before do
      tracks.each_with_index do |track, idx|
        track.update(duration: track.duration + (idx * 10))
        create_list(:like, 10 - idx, likable: track)
      end
    end

    it 'sorting' do
      visit tag_path(tag)
      click_button('Tracks: 3') # rubocop:disable Capybara/ClickLinkOrButtonStyle

      expect_track_sorting_controls(tracks)
    end
  end
end
