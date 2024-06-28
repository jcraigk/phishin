require 'rails_helper'

describe 'Ambiguous slug resolution', :js do
  let!(:show3) { create(:show, date: '2014-10-31', tour:) }
  let!(:show4) { create(:show, :with_tracks, date: '2014-11-02', tour:) }
  let!(:venue) { create(:venue, name: 'Madison Square Garden') }
  let!(:tour) { create(:tour, name: 'Magical Myster Tour') }

  before do
    create(:show, date: '1995-10-31', tour:, venue:)
    create(:show, date: '1998-10-31', tour:, venue:)
  end

  shared_examples 'day of year' do
    it 'display expected content' do
      within('#title_box') do
        expect_content('October 31')
      end

      within('#content_box') do
        expect_content('Today in History')
      end

      items = page.all('ul.item_list li')
      expect(items.size).to eq(3)

      first('ul.item_list li a').click
      expect(page).to have_current_path("/#{show3.date}")
    end
  end

  describe '/today' do
    before do
      travel_to Time.use_zone(TIME_ZONE) { Time.zone.local(2012, 10, 31) }
      visit '/today'
    end

    include_examples 'day of year'
  end

  describe 'explicit day of year' do
    before { visit '/october-31' }

    include_examples 'day of year'
  end

  it 'year' do
    visit '/2014'

    within('#title_box') do
      expect_content('Year of 2014', 'Total shows: 2')
    end

    within('#content_box') do
      expect_content(tour.name)
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(2)

    first('ul.item_list li a').click
    expect(page).to have_current_path("/#{show4.date}")
  end

  it 'year range' do
    visit '/1998-2014'

    within('#title_box') do
      expect_content('Years: 1998-2014', 'Total shows: 3')
    end

    within('#content_box') do
      expect_content(tour.name)
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(3)

    first('ul.item_list li a').click
    expect(page).to have_current_path("/#{show4.date}")
  end

  it 'date' do
    visit '/2014-11-02'

    within('#title_box') do
      expect_content('Nov 2, 2014')
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(show4.tracks.size)
  end

  it 'song' do
    song = create(:song, title: 'You Enjoy Myself', alias: 'YEM')
    song.tracks << create(:track, show: show4)

    visit "/#{song.slug}"

    within('#title_box') do
      expect_content('You Enjoy Myself (aka YEM)', "Total tracks: #{song.tracks.size}")
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(song.tracks.size)
  end

  it 'venue' do
    visit "/#{venue.slug}"

    within('#title_box') do
      expect_content(venue.name, venue.location, "Total shows: #{venue.shows.size}")
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(venue.shows.size)
  end

  it 'tour' do
    visit "/#{tour.slug}"

    within('#title_box') do
      expect_content(tour.name, "Total shows: #{tour.shows.size}")
    end

    items = page.all('ul.item_list li')
    expect(items.size).to eq(tour.shows.size)
  end
end
