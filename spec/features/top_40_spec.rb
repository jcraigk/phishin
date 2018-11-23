# frozen_string_literal: true
require 'rails_helper'

feature 'Top 40', :js do
  given!(:shows) { create_list(:show, 42, :with_likes) }
  given!(:tracks) { create_list(:track, 42, :with_likes) }

  scenario 'visit Top 40 page' do
    visit top_shows_path

    # Top 40 Shows
    within('#title_box') do
      expect_content('Top 40 Shows')
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(40)

    # Top 40 Tracks
    click_link('Top 40 Tracks')

    within('#title_box') do
      expect_content('Top 40 Tracks')
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(40)
  end
end
