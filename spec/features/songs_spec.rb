# frozen_string_literal: true
require 'rails_helper'

feature 'Songs', :js do
  given!(:a_song) { create(:song, :with_tracks, title: 'A Apolitical Blues') }
  given(:titles) { ['Garden Party', 'Gettin Jiggy', 'Ghost'] }
  given!(:g_songs) do
    titles.each_with_object([]) do |title, songs|
      songs << create(:song, :with_tracks, title: title)
    end
  end
  given(:song1) { g_songs.first }
  given(:song2) { g_songs.second }
  given(:song3) { g_songs.third }

  before do
    create_list(:track, 2, songs: [g_songs.first])
    create_list(:track, 3, songs: [g_songs.second])
  end

  scenario 'visit Songs page' do
    visit songs_path

    within('#title_box') do
      expect_content("'A' Songs", 'Total Songs: 1')
    end

    within('#sub_nav') do
      expect_content('ABCDEFGHIJKLMNOPQRSTUVWXYZ#')
    end

    within('#content_box') do
      expect_content(a_song.title)
    end

    # Click on sub nav 'G'
    within('#sub_nav') do
      click_link('G')
    end

    within('#title_box') do
      expect_content("'G' Songs", "Total Songs: #{g_songs.count}")
    end

    within('#content_box') do
      expect_content(*titles)
    end

    # Click on first song
    first('ul.item_list li').click
    expect(page).to have_current_path("/#{g_songs.first.slug}")
  end

  scenario 'Song sorting' do
    visit songs_path(char: 'G')

    # Default sort by Title
    within('#title_box') do
      expect_content('Sort by', 'Title')
    end
    expect_content_in_order([song1, song2, song3].map(&:title))

    # Sort by Track Count
    within('#title_box') do
      first('.btn-group').click
      click_link('Track Count')
      expect_content('Sort by', 'Track Count')
    end
    expect_content_in_order([song2, song1, song3].map(&:title))
  end
end
