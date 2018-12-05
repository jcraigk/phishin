# frozen_string_literal: true
require 'rails_helper'

feature 'Song page', :js do
  given(:song) { create(:song) }
  given!(:tracks) { create_list(:track, 3, songs: [song]) }
  given(:titles_by_date) { tracks.sort_by { |t| t.show.date }.map(&:title) }
  given(:titles_by_likes) { tracks.sort_by { |t| t.likes_count }.map(&:title) }
  given(:titles_by_duration) { tracks.sort_by { |t| t.duration }.map(&:title) }

  before do
    tracks.each_with_index do |track, idx|
      track.update(duration: track.duration + idx * 10)
      track.likes = create_list(:like, 10 - idx, likable: track)
    end
  end

  scenario 'sorting' do
    visit "/#{song.slug}"

    # Default sort by Reverse date
    within('#title_box') do
      expect_content('Sort by', 'Reverse Date')
    end
    expect_content_in_order(titles_by_date.reverse)

    # Sort by Date
    # within('#title_box') do
    #   first('.btn-group').click
    #   click_link('Date')
    #   expect_content('Sort by', 'Date')
    # end
    # expect_content_in_order(titles_by_date)

    # Sort by Likes
    within('#title_box') do
      first('.btn-group').click
      click_link('Likes')
      expect_content('Sort by', 'Likes')
    end
    expect_content_in_order(titles_by_likes)

    # Sort by Duration
    within('#title_box') do
      first('.btn-group').click
      click_link('Duration')
      expect_content('Sort by', 'Duration')
    end
    expect_content_in_order(titles_by_duration)
  end
end
