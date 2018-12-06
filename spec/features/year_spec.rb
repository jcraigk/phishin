# frozen_string_literal: true
require 'rails_helper'

feature 'Year spec', :js do
  given!(:shows) { create_list(:show, 3) }
  given(:dates_by_date) { shows.sort_by(&:date).map(&:date_with_dots) }
  given(:dates_by_likes) { shows.sort_by(&:likes_count).map(&:date_with_dots) }
  given(:dates_by_duration) { shows.sort_by(&:duration).map(&:date_with_dots) }

  before do
    shows.each_with_index do |show, idx|
      show.update(
        duration: show.duration + idx * 10,
        date: "2018-01-#{idx + 1}"
      )
      show.likes = create_list(:like, 10 - idx, likable: show)
    end
  end

  scenario 'visit Year path; sorting, liking' do
    visit '/2018'

    within('#title_box') do
      expect_content('Shows: 3', 'Sort by', 'Reverse Date')
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
