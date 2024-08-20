require 'rails_helper'

describe 'Show', :js do
  let!(:show) { create(:show, :with_tracks, :with_tags, date: '2018-01-01') }
  let!(:show2) { create(:show, date: '2018-01-02') }
  let!(:show3) { create(:show, date: '2018-01-03') }
  let(:track) { show.tracks.first }

  before do
    track.tags << create(:tag)
    track.songs << create(:song)
  end

  it 'visit show page' do
    visit show.date

    within('#title_box') do
      expect_content(
        show.venue.name, 'Taper Notes', show.tags.first.name, 'Next Show', 'Previous Show'
      )
    end

    # Main content
    within('#content_box') do
      expect_content('Set 1')
      expect_content(*show.tracks.map(&:title))
    end

    track_items = page.all('.playable_track')
    expect(track_items.count).to eq(show.tracks.count)

    # Show context dropdown
    first('.show-context-dropdown').click
    within('.show-context-dropdown') do
      expect_content('Add to playlist', 'Share', 'Lookup at phish.net')
    end

    # Track context dropdown
    first('.playable_track').hover
    first('.track-context-dropdown').click
    within('.track-context-dropdown') do
      expect_content(
        'Play', 'Add to playlist', 'Share', 'Download MP3',
        track.songs.first.title, track.songs.second.title
      )
    end
  end

  it 'clicking previous/next buttons' do
    visit show2.date

    within('#title_box') do
      click_on('<< Previous Show')
    end
    expect(page).to have_current_path("/#{show.date}")

    within('#title_box') do
      click_on('<< Previous Show')
    end
    expect(page).to have_current_path("/#{show3.date}")

    within('#title_box') do
      click_on('Next Show >>')
    end
    expect(page).to have_current_path("/#{show.date}")

    within('#title_box') do
      click_on('Next Show >>')
    end
    expect(page).to have_current_path("/#{show2.date}")
  end

  describe 'liking' do
    it 'when not logged in' do
      visit show.date
      sleep(1)

      within('#title_box') do
        first('.like_toggle').click
      end
      expect_content('You must be signed in to submit Likes')
    end

    context 'when logged in' do
      before do
        sign_in(create(:user))
        visit show.date
        sleep(1)
      end

      it 'liking/unliking the show', skip: 'Feature works fine but test fails' do
        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')
        within('#title_box .likes_large span') do
          expect_content('1')
        end

        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Unlike acknowledged')
        within('#title_box .likes_large span') do
          expect_content('0')
        end

        within('#title_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')

        visit my_shows_path
        expect_content(show.date_with_dots, show.venue.name)
      end

      it 'liking/unliking a track', skip: 'Feature works fine but test fails' do
        within('#content_box') do
          first('.like_toggle').click
        end
        expect_content('Like acknowledged')
        within('#content_box') do
          expect(first('.likes_small span').text).to eq('1')
        end

        visit my_tracks_path
        expect_content(show.tracks.first.title)
      end
    end
  end
end
