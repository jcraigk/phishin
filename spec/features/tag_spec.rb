# frozen_string_literal: true
require 'rails_helper'

feature 'Tag page', :js do
  given(:tag) { create(:tag) }

  context 'shows' do
    given!(:shows) { create_list(:show, 3, tags: [tag]) }
    given(:dates_by_date) { shows.sort_by(&:date).map(&:date_with_dots) }
    given(:dates_by_likes) { shows.sort_by(&:likes_count).map(&:date_with_dots) }
    given(:dates_by_duration) { shows.sort_by(&:duration).map(&:date_with_dots) }

    before do
      shows.each_with_index do |show, idx|
        show.update(duration: show.duration + idx * 10)
        show.likes = create_list(:like, 10 - idx, likable: show)
      end

      visit tag_path(tag)
      click_button('Shows: 3')
    end

    scenario 'sorting' do
      # Default sort by Reverse date
      within('#title_box') do
        expect_content('Sort by', 'Reverse Date')
      end
      expect_content_in_order(dates_by_date.reverse)

      # Sort by Date
      # within('#title_box') do
      #   first('.dropdown-toggle').click
      #   click_link('Date')
      #   expect_content('Sort by', 'Date')
      # end
      # expect_content_in_order(dates_by_date)

      # Sort by Likes
      within('#title_box') do
        first('.dropdown-toggle').click
        click_link('Likes')
        expect_content('Sort by', 'Likes')
      end
      expect_content_in_order(dates_by_likes)

      # Sort by Duration
      within('#title_box') do
        first('.dropdown-toggle').click
        click_link('Duration')
        expect_content('Sort by', 'Duration')
      end
      expect_content_in_order(dates_by_duration)
    end
  end

  context 'tracks' do
    given!(:tracks) { create_list(:track, 3, tags: [tag]) }
    given(:titles_by_date) { tracks.sort_by { |t| t.show.date }.map(&:title) }
    given(:titles_by_likes) { tracks.sort_by { |t| t.likes_count }.map(&:title) }
    given(:titles_by_duration) { tracks.sort_by(&:duration).map(&:title) }

    before do
      tracks.each_with_index do |track, idx|
        track.update(duration: track.duration + idx * 10)
        track.likes = create_list(:like, 10 - idx, likable: track)
      end

      visit tag_path(tag)
      click_button('Tracks: 3')
    end

    scenario 'sorting' do
      # Default sort by Reverse date
      within('#title_box') do
        expect_content('Sort by', 'Reverse Date')
      end
      expect_content_in_order(titles_by_date.reverse)

      # Sort by Date
      # within('#title_box') do
      #   first('.dropdown-toggle').click
      #   click_link('Date')
      #   expect_content('Sort by', 'Date')
      # end
      # expect_content_in_order(titles_by_date)

      # Sort by Likes
      within('#title_box') do
        first('.dropdown-toggle').click
        click_link('Likes')
        expect_content('Sort by', 'Likes')
      end
      expect_content_in_order(titles_by_likes)

      # Sort by Duration
      within('#title_box') do
        first('.dropdown-toggle').click
        click_link('Duration')
        expect_content('Sort by', 'Duration')
      end
      expect_content_in_order(titles_by_duration)
    end
  end
end
