# frozen_string_literal: true
require 'rails_helper'

feature 'Play Random Show', :js do
  given!(:show) { create_list(:show, 2, :with_tracks) }

  scenario 'click Play button to play random show' do
    visit root_path

    find('#control_playpause').click
    expect_content('Playing random show...')

    expect(page.current_path).to match(/\d{4}-\d{2}-\d{2}/)
  end
end
