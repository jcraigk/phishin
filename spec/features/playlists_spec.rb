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
    xscenario 'editing and saving a playlist' do
    end

    xscenario 'accessing a previously saved playlist' do
    end
  end
end
