require 'rails_helper'

describe 'Show Context Menus', :js do
  let(:show) { create(:show, :with_tracks) }
  let(:track) { show.tracks.first }

  it 'use the show dropdown' do
    visit show.date
    sleep(1)

    first('.show-context-dropdown').click
    expect_content('Lookup at phish.net')
    click_link('Add to playlist')
    expect_content('Tracks from show added to playlist')

    first('.show-context-dropdown').click
    click_link('Share')
    expect_content('Link copied to clipboard')
  end
end
