require 'rails_helper'

describe 'My Tracks', :js do
  let(:user) { create(:user) }
  let(:tracks) { create_list(:track, 3) }

  before do
    tracks.each_with_index do |track, idx|
      create(:like, likable: track, user:)
      create_list(:like, 10 - idx, likable: track)
      track.update(duration: track.duration + (idx * 10))
    end

    sign_in(user)
  end

  it 'click My Tracks, display/sorting of tracks' do
    visit root_path

    find_by_id('user_controls').click
    click_on('My Track')

    expect(page).to have_current_path(my_tracks_path)

    expect_track_sorting_controls(tracks)
  end
end
