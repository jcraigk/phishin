# frozen_string_literal: true
require 'rails_helper'

describe 'Search', :js do
  let(:term) { 'hood' }
  let(:date) { '1995-10-31' }

  before do
    create(:song, :with_tracks, title: 'Harry Hood')
    create(:song, :with_tracks, title: 'Antelope')
    create(:venue, :with_shows, name: 'Hood Amphitheater')
    create(:venue, :with_shows, city: 'Hoodtown')
    create(:tour, :with_shows, name: '1993 Hoodlum Tour')
    create(:show, date: date)
  end

  it 'visit Playlists page' do
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
