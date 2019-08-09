# frozen_string_literal: true
require 'rails_helper'

describe 'Search', :js do
  context 'with invalid search term' do
    let(:term) { 'a' }

    it 'returns error message and instructions' do
      enter_search_term(term)

      within('#content_box') do
        expect_content('Search term must be at least 3 characters long')
      end
    end
  end

  context 'with valid search term' do
    context 'when no data matches' do
      let(:term) { 'azdsd' }
      let(:paragraph) do
        <<~TXT
          Got a blank space where results should be...
          If searching for a date, enter it like "12/31/95" or "1995-12-31"
          If searching for a day of the year (like Halloween), search for an instance like "10/31/94"
          If searching for a venue, enter part of its name (or past names) or location like "msg" or "new york"
          If searching for a song, enter all or part of its name like "also sprach" or "birdwatcher"
          If searching for a tour, enter all or part of its name like "summer" or "1995"
          If searching for a tag, enter all or part of its name or description like "sbd" or "soundboard"
          If searching for a tag instance, enter part of its notes like "vaccuum solo"
        TXT
      end

      it 'returns no results' do
        enter_search_term(term)

        within('#content_box') do
          expect_content(paragraph.strip)
        end
      end
    end

    context 'with text-based term' do
      let(:term) { 'hood' }

      before do
        create(:song, :with_tracks, title: 'Harry Hood')
        create(:song, :with_tracks, title: 'Antelope')
        create(:venue, :with_shows, name: 'Hood Amphitheater')
        create(:venue, :with_shows, city: 'Hoodtown')
        create(:tour, :with_shows, name: '1993 Hoodlum Tour')
        create(:tag, name: 'Hoodiness')
        create(:tag, name: 'Another')
        create(:show_tag, notes: '...and then there was Hood and it was good...')
        create(:track_tag, notes: '...busted out Hood!')
      end

      it 'returns expected results' do
        enter_search_term(term)

        within('#content_box') do
          expect_content(
            'Matched 1 Song',
            'Matched 2 Venues',
            'Matched 1 Tour',
            'Matched 1 Tag',
            'Matched 1 Show Tag Note',
            'Matched 1 Track Tag Note'
          )
        end
      end
    end

    context 'with date-based term' do
      let(:term) { '1995-10-31' }
      let(:date) { Date.parse(term) }

      before do
        create(:show, date: date)
        create(:show, date: date + 1.day)
        create(:show, date: date - 1.year)
        create(:show, date: date - 2.years)
        create(:show, date: date - 2.years - 1.day)
      end

      it 'returns expected results' do
        enter_search_term(term)

        within('#content_box') do
          expect_content(
            'Matched 1 Date Exactly',
            'Matched 2 Days in History'
          )
        end
      end
    end
  end
end
