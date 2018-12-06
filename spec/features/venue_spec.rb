# frozen_string_literal: true
require 'rails_helper'

feature 'Venue page', :js do
  given(:venue) { create(:venue) }
  given!(:shows) { create_list(:show, 3, venue: venue) }
  given(:dates_by_date) { shows.sort_by(&:date).map(&:date_with_dots) }
  given(:dates_by_likes) { shows.sort_by(&:likes_count).map(&:date_with_dots) }
  given(:dates_by_duration) { shows.sort_by(&:duration).map(&:date_with_dots) }

  before do
    shows.each_with_index do |show, idx|
      show.update(duration: show.duration + idx * 10)
      show.likes = create_list(:like, 10 - idx, likable: show)
    end
  end

  scenario 'sorting' do
    visit "/#{venue.slug}"
    expect_content('Shows: 3')

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
