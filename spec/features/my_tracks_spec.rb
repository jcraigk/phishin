# frozen_string_literal: true
require 'rails_helper'

feature 'My Tracks', :js do
  given(:user) { create(:user) }

  before { login_as(user) }

  scenario 'click My Tracks from user dropdown' do
    visit root_path

    find('#user_controls').click
    click_link('My Track')

    expect(page).to have_current_path(my_tracks_path)
  end

  context 'when user has liked tracks' do
    given(:tracks) { create_list(:track, 3) }

    before do
      create(:like, likable: tracks.first, user: user)
      create(:like, likable: tracks.second, user: user)
    end

    scenario 'My Tracks displays liked tracks' do
      visit my_tracks_path

      items = page.all('ul.item_list li')
      expect(items.count).to eq(2)
      expect_content(tracks.first.title, tracks.second.title)

      first('ul.item_list li a').click
      expect(page.current_path).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end
end
