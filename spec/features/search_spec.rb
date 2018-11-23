# frozen_string_literal: true
require 'rails_helper'

feature 'Search', :js do
  given(:term) { 'hood' }
  given!(:song1) { create(:song, :with_tracks, title: 'Harry Hood') }
  given!(:song2) { create(:song, :with_tracks, title: 'Antelope') }
  given!(:venue1) { create(:venue, :with_shows, name: 'Hood Amphitheater') }
  given!(:venue2) { create(:venue, :with_shows, city: 'Hoodtown') }
  given!(:tour) { create(:tour, :with_shows, name: '1993 Hoodlum Tour') }
  given(:date) { '1995-10-31' }
  given!(:show) { create(:show, date: date) }


  scenario 'visit Playlists page' do
    visit root_path

    # Word-based search
    fill_in('term', with: term)
    find('#search_term').native.send_keys(:return)

    within('#title_box') do
      expect_content("Search: '#{term}'")
    end

    within('#content_box') do
      expect_content('Matched 1 Song', 'Matched 2 Venues', 'Matched 1 Tour')
    end
  end
end
