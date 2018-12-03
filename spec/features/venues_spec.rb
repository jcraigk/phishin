# frozen_string_literal: true
require 'rails_helper'

feature 'Venues', :js do
  given!(:a_venue) { create(:venue, :with_shows, name: 'Alpine Valley Music Theater') }
  given(:names) { ['Eagles Ballroom', 'Earlham College', 'Eastbrook Theatre'] }
  given!(:e_venues) do
    names.each_with_object([]) do |name, venues|
      venues << create(:venue, :with_shows, name: name)
    end
  end
  given(:venue1) { e_venues.first }
  given(:venue2) { e_venues.second }
  given(:venue3) { e_venues.third }

  before do
    create_list(:show, 2, venue: venue1)
    create_list(:show, 3, venue: venue3)
  end

  scenario 'visit Venues page' do
    visit venues_path

    within('#title_box') do
      expect_content("'A' Venues", 'Total Venues: 1')
    end

    within('#sub_nav') do
      expect_content('ABCDEFGHIJKLMNOPQRSTUVWXYZ#')
    end

    within('#content_box') do
      expect_content(a_venue.name)
    end

    # Click on 'G'
    within('#sub_nav') do
      click_link('E')
    end

    within('#title_box') do
      expect_content("'E' Venues", "Total Venues: #{e_venues.count}")
    end

    within('#content_box') do
      expect_content(*names)
    end

    # Click on first venue
    first('ul.item_list li h2 a').click
    expect(page).to have_current_path("/#{e_venues.first.slug}")
  end

  scenario 'Venue sorting' do
    visit venues_path(char: 'E')

    expect_content_in_order('Eagles', 'Earlham')

    # Default sort by Name
    within('#title_box') do
      expect_content('Sort by', 'Name')
    end
    expect_content_in_order([venue1, venue2, venue3].map(&:name))

    # Sort by Track Count
    within('#title_box') do
      first('.btn-group').click
      click_link('Show Count')
      expect_content('Sort by', 'Show Count')
    end
    expect_content_in_order([venue3, venue1, venue2].map(&:name))
  end
end
