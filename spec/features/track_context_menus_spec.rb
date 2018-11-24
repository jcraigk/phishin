# frozen_string_literal: true
require 'rails_helper'

feature 'Track Context Menues', :js do
  given(:show) { create(:show, :with_tracks) }
  given(:track) { show.tracks.first }

  xscenario 'open the dropdown' do
    visit show.date
  end
end
