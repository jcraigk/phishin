require 'rails_helper'

describe 'Homepage', :js do
  let(:venue) { create(:venue) }
  let(:most_recent_year) { ERAS.values.flatten.last }
  let!(:shows) do
    [ 1983, most_recent_year ].each_with_object([]) do |year, shows|
      (1..3).each do |day|
        shows << create(:show, venue:, date: "#{year}-01-#{day}")
      end
    end
  end

  before do
    shows.last.update(venue: create(:venue))
  end

  it 'visit root path' do
    visit root_path

    # Top section
    within('#page_header') do
      within('#player_container #user_controls') do
        expect_content('Sign in')
      end
      expect_css('#logo')
      within('#player_controls') do
        expect_css('#control_previous', '#control_playpause', '#control_next')
      end
    end

    # Nav
    within('#global_nav_container #global_nav') do
      expect_content('Years', 'Venues', 'Songs', 'Map', 'Top 40', 'Playlists', 'Tags')
      expect_css('#search_box')
    end

    # Title box
    within('#title_box') do
      expect_content('LIVE PHISH AUDIO STREAMS', 'iOS app')
    end

    # Main content
    within('#content_box') do
      # Era titles
      expect_content('3.0 Era', '2.0 Era', '1.0 Era')

      # Years
      years = page.all('ul.item_list li h2.wider')
      expect(years.first.text).to eq('2024')
      expect(years.last.text).to eq('1983-1987')

      # Venue stats
      years = page.all('ul.item_list li h4.narrow')
      expect(years.first.text).to eq('2 venues')
      expect(years[10].text).to eq('0 venues')
      expect(years.last.text).to eq('1 venue')

      # Show stats
      years = page.all('ul.item_list li h3.alt')
      expect(years.first.text).to eq('3 shows')
      expect(years[10].text).to eq('0 shows')
      expect(years.last.text).to eq('3 shows')
    end

    within('#footer') do
      expect_content('phish.in', 'faq', 'contact', 'api', 'tag.in project')
    end

    # Click most recent year
    click_on(most_recent_year)

    within('#title_box') do
      expect_content(most_recent_year, 'Total shows: 3')
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(3)
  end
end
