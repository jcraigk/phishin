require 'rails_helper'

RSpec.describe 'MapView', type: :feature, js: true do
  let(:coordinates) { { lng: -122.4194, lat: 37.7749 } }
  let(:venues) do
    [
      {
        name: 'The Warfield',
        location: 'San Francisco, CA',
        shows_count: 5,
        latitude: 37.7833,
        longitude: -122.4167,
        shows: [
          { date: '2024-01-01' },
          { date: '2024-02-01' }
        ]
      },
      {
        name: 'Bill Graham Civic Auditorium',
        location: 'San Francisco, CA',
        shows_count: 2,
        latitude: 37.7793,
        longitude: -122.4185,
        shows: [
          { date: '2024-03-01' }
        ]
      }
    ]
  end

  before do
    visit '/map'
  end

  it 'renders the map on the page', skip: "Map does not render in test env" do
    expect(page).to have_css('.map-container')

    # Displays markers for each venue
    venues.each do |venue|
      expect(page).to have_content(venue[:name])
      expect(page).to have_content(venue[:location])
    end

    # Displays popups for venues with shows
    venues.each do |venue|
      venue[:shows].each do |show|
        expect(page).to have_link(show[:date].gsub("-", "."), href: "/#{show[:date]}")
      end
    end
  end

  it 'displays "No results found" when there are no venues', skip: "Map does not render in test env" do
    visit '/map'

    # Simulate the case with no venues
    page.execute_script('document.querySelector(".map-container").__vue__.venues = []')
    expect(page).to have_content('No results found for your search.')
  end
end
