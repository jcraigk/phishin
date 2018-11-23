# frozen_string_literal: true
require 'rails_helper'

feature 'Show', :js do
  given(:show) { create(:show, :with_tracks, :with_likes, :with_tags) }
  given(:track) { show.tracks.first }

  before do
    track.tags << create(:tag)
  end

  scenario 'visit show page' do
    visit show.date

    within('#title_box') do
      expect_content(
        show.venue.name,
        'Taper Notes',
        show.tags.first.name,
        'Next Show',
        'Previous Show'
      )
    end

    # Main content
    within('#content_box') do
      expect_content('Set 1')
    end

    # TODO: Test show dropdown menu
    # TODO: Test track dropdown menu
  end
end
