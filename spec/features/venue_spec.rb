# frozen_string_literal: true
require 'rails_helper'

feature 'Venue page', :js do
  given(:venue) { create(:venue, :with_shows) }

  # TODO: setup likes and durations

  xscenario 'sorting' do
    visit venue_path(venue)
    # expect shows in order based on sorting
  end
end
