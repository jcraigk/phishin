# frozen_string_literal: true
require 'rails_helper'

feature 'Venues', :js do
  given(:venues) { create_list(:venue, 30, :with_shows) }
  given(:a_name) { 'Alpine Valley Music Theater' }
  given(:g_name) { 'Great Woods' }
  given(:a_name_count) { venues.select { |v| v.name.start_with?('A') }.size }
  given(:g_name_count) { venues.select { |v| v.name.start_with?('G') }.size }

  before do
    venues.first.update(name: a_name)
    venues.second.update(name: g_name)
  end

  scenario 'visit Venues page' do
    visit venues_path

    within('#title_box') do
      expect_content("'A' Venues", "Total Venues: #{a_name_count}")
    end

    within('#sub_nav') do
      expect_content('ABCDEFGHIJKLMNOPQRSTUVWXYZ#')
    end

    within('#content_box') do
      expect_content(a_name)
    end

    # Click on 'G'
    within('#sub_nav') do
      click_link('G')
    end

    within('#title_box') do
      expect_content("'G' Venues", "Total Venues: #{g_name_count}")
    end

    within('#content_box') do
      expect_content(g_name)
    end
  end
end
