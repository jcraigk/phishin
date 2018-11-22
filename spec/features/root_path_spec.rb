# frozen_string_literal: true
require 'rails_helper'

feature 'Main pages', :js do
  context 'not logged in' do
    given(:venue) { create(:venue) }

    before do
      [1987, ERAS.values.flatten .last].each do |year|
        (1..5).each do |day|
          create(:show, venue: venue, date: "#{year}-01-#{day}")
        end
      end
    end

    scenario 'main page' do
      visit root_path

      # Title box
      within('#title_box') do
        expect(page).to have_content('LIVE PHISH AUDIO STREAMS')
        expect(page).to have_content('iOS app')
        expect(page).to have_content('Android app')
      end

      # Era titles
      within('#content_box') do
        expect(page).to have_content('3.0 Era')
        expect(page).to have_content('2.0 Era')
        expect(page).to have_content('1.0 Era')
      end

      # Years
      years = page.all('ul.item_list li h2.wider')
      expect(years.first.text).to eq('2018')
      expect(years[10].text).to eq('2004')
      expect(years.last.text).to eq('1983-1987')

      # Venue stats
      years = page.all('ul.item_list li h4.narrow')
      expect(years.first.text).to eq('1 venue')
      expect(years[10].text).to eq('0 venues')
      expect(years.last.text).to eq('1 venue')

      # Show stats
      years = page.all('ul.item_list li h3.alt')
      expect(years.first.text).to eq('5 shows')
      expect(years[10].text).to eq('0 shows')
      expect(years.last.text).to eq('5 shows')
    end
  end
end
