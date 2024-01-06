require 'rails_helper'

describe 'Playlists', :js do
  xcontext 'when not logged in' do # Commented due to flakiness when run with full suite
    it 'visit Playlists page' do
      visit active_playlist_path
      sleep(1)

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
      end

      within('#content_box') do
        expect_content('Your active playlist is empty.')
      end

      # Saved Playlists
      within('#sub_nav') do
        click_on('Saved')
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
    let(:user) { create(:user) }
    let!(:show) { create(:show, :with_tracks, date: "#{ERAS.values.flatten.last}-01-01") }

    before { login_as(user) }

    it 'editing' do
      visit active_playlist_path

      # Click EDIT PLAYLIST
      accept_confirm do
        click_on('EDIT PLAYLIST')
      end
      expect_content('PLAYLIST EDIT MODE')

      # Go to show, click on first three tracks
      click_on('Years')
      first('ul.item_list li').click
      first('ul.item_list li a').click
      track_items = page.all('ul.item_list li')
      track_items[0].click
      track_items[1].click
      track_items[2].click
      expect_content('Track added to playlist')

      # Return to playlist, ensure tracks are there
      within('#global_nav') do
        click_on('Playlists')
      end
      track_items = page.all('.playable_track')
      expect(track_items.size).to eq(3)
      expect_content_in_order(show.tracks)

      # Click DONE EDITING
      click_on('DONE EDITING')
      expect(page).to have_no_content('PLAYLIST EDIT MODE')
    end

    xit 'saving (including invalid name/slug, no tracks)' do
    end

    context 'with saved playlist' do
      let!(:playlist) { create(:playlist, user:) }

      it 'opening a saved playlist' do
        visit stored_playlists_path

        click_on(playlist.name)
        expect(page).to have_current_path("/play/#{playlist.slug}")
      end

      xit 'reordering a playlist' do
      end
    end
  end
end
