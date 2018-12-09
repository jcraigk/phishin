# frozen_string_literal: true
require 'rails_helper'

feature 'Venue page', :js do
  given(:venue) { create(:venue) }
  given(:shows) { create_list(:show, 3, venue: venue) }

  before do
    shows.each_with_index do |show, idx|
      show.update(duration: show.duration + idx * 10)
      create_list(:like, 10 - idx, likable: show)
    end
  end

  scenario 'sorting' do
    visit "/#{venue.slug}"
    expect_content('Shows: 3')

    expect_show_sorting_controls(shows)
  end
end
