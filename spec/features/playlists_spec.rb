# frozen_string_literal: true
require 'rails_helper'

feature 'Playlists', :js do
  context 'when not logged in' do
    scenario 'visit Playlists page' do
      visit active_playlist_path

      # Active Playlist
      within('#title_box') do
        expect_content(
          '(Untitled Playlist)',
          'Sign in to create and share custom playlists!'
        )
        within('#playlist_mode_btn') do
          expect_content('EDIT PLAYLIST')
        end
        within('#clear_playlist_btn') do
          expect_content('EMPTY')
        end
        within('#share_playlist_btn') do
          expect_content('SHARE')
        end
      end

      within('#content_box') do
        expect_content('Your active playlist is empty.')
      end

      # Saved Playlists
      within('#sub_nav') do
        click_link('Saved')
      end

      within('#title_box') do
        expect_content('Saved Playlists')
      end

      within('#content_box') do
        expect_content('You must sign in to manage saved playlists')
      end
    end
  end

  context 'when logged in' do
    given(:user) { create(:user) }
    given!(:show) { create(:show, :with_tracks, date: "#{ERAS.values.flatten.last}-01-01") }

    before { login_as(user) }

    scenario 'editing and saving a playlist' do
      visit active_playlist_path

      # Click EDIT PLAYLIST
      accept_confirm do
        click_button('EDIT PLAYLIST')
      end
      expect_content('PLAYLIST EDIT MODE')

      # Go to show, click on first three tracks
      click_link('Years')
      first('ul.item_list li').click
      first('ul.item_list li a').click
      track_items = page.all('ul.item_list li')
      track_items[0].click
      track_items[1].click
      track_items[2].click
      expect_content('Track added to playlist')

      # Return to playlist, ensure tracks are there
      within('#global_nav') do
        click_link('Playlists')
      end
      track_items = page.all('.playable_track')
      expect(track_items.size).to eq(3)
      expect_content_in_order(show.tracks)

      # Click DONE EDITING
      click_button('DONE EDITING')
      expect(page).not_to have_content('PLAYLIST EDIT MODE')
    end

    xscenario 'reordering a playlist' do
    end

    xscenario 'opening a saved playlist' do
    end
  end
end
