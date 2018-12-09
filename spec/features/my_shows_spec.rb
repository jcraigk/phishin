# frozen_string_literal: true
require 'rails_helper'

feature 'My Shows', :js do
  given(:user) { create(:user) }
  given(:shows) { create_list(:show, 3) }

  before do
    shows.each_with_index do |show, idx|
      create(:like, likable: show, user: user)
      show.update(duration: show.duration + idx * 10)
      create_list(:like, 10 - idx, likable: show)
    end

    login_as(user)
  end

  scenario 'click My Shows, display/sorting of shows' do
    visit root_path

    find('#user_controls').click
    click_link('My Shows')

    expect(page).to have_current_path(my_shows_path)

    expect_show_sorting_controls(shows)
  end
end
