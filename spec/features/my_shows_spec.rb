# frozen_string_literal: true
require 'rails_helper'

feature 'My Shows', :js do
  given(:user) { create(:user) }

  before { login_as(user) }

  scenario 'click My Shows from user dropdown' do
    visit root_path

    find('#user_controls').click
    click_link('My Shows')

    expect(page).to have_current_path(my_shows_path)
  end

  context 'when user has liked shows' do
    given(:shows) { create_list(:show, 3) }

    before do
      create(:like, likable: shows.first, user: user)
      create(:like, likable: shows.second, user: user)
    end

    scenario 'My Shows displays liked shows' do
      visit my_shows_path

      items = page.all('ul.item_list li')
      expect(items.count).to eq(2)

      first('ul.item_list li a').click
      expect(page.current_path).to match(/\d{4}-\d{2}-\d{2}/)
    end

    xscenario 'sorting' do
    end
  end
end
