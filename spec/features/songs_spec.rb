require 'rails_helper'

describe 'Songs', :js do
  let(:titles) { [ 'Garden Party', 'Gettin Jiggy', 'Ghost' ] }
  let!(:g_songs) do
    titles.each_with_object([]) do |title, songs|
      songs << create(:song, :with_tracks, title:)
    end
  end
  let(:song1) { g_songs.first }
  let(:song2) { g_songs.second }
  let(:song3) { g_songs.third }

  before do
    create(:song, :with_tracks, title: 'A Apolitical Blues', alias: 'Blues')
    create_list(:track, 2, songs: [ g_songs.first ])
    create_list(:track, 3, songs: [ g_songs.second ])
  end

  it 'visit Songs page' do
    visit songs_path

    within('#title_box') do
      expect_content("'A' Songs", 'Total: 1')
    end

    within('#sub_nav') do
      expect_content('ABCDEFGHIJKLMNOPQRSTUVWXYZ#')
    end

    within('#content_box') do
      expect_content('A Apolitical Blues (aka Blues)')
    end

    # Click on sub nav 'G'
    within('#sub_nav') do
      click_on('G')
    end

    within('#title_box') do
      expect_content("'G' Songs", "Total: #{g_songs.count}")
    end

    within('#content_box') do
      expect_content(*titles)
    end

    # Click on first song
    first('ul.item_list li').click
    expect(page).to have_current_path("/#{g_songs.first.slug}")
  end

  it 'Song sorting' do
    visit songs_path(char: 'G')

    # Default sort by Title
    within('#title_box') do
      expect_content('Sort', 'Title')
    end
    expect_content_in_order([ song1, song2, song3 ].map(&:title))

    # Sort by Track Count
    within('#title_box') do
      first('.btn-group').click
      click_on('Track Count')
      expect_content('Sort', 'Track Count')
    end
    expect_content_in_order([ song2, song1, song3 ].map(&:title))
  end
end
