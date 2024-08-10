require 'rails_helper'

describe 'Tags', :js do
  let(:tag_names) { %w[Awesome Boppin Cool] }
  let!(:tags) do
    tag_names.each_with_object([]) do |name, tags|
      tags << create(:tag, :with_tracks, :with_shows, name:)
    end
  end
  let(:tag1) { tags.first }
  let(:tag2) { tags.second }
  let(:tag3) { tags.third }

  before do
    create_list(:show, 2, tags: [ tag1 ])
    create_list(:show, 3, tags: [ tag2 ])
    create_list(:track, 5, tags: [ tag1 ])
    create_list(:track, 7, tags: [ tag3 ])
  end

  # TODO: Overlapping elements here
  xit 'visit Tags page, select tag, select a show' do
    visit tags_path

    within('#title_box') do
      expect_content('All Tag', "Total Tags: #{tags.count}")
    end

    within('#content_box') do
      expect_content(*tags.map(&:name))
      expect_content('2 shows')
      expect_content('2 tracks')
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tags.count)

    # Click first tag
    click_on(tag1.name)

    within('#title_box') do
      expect_content(
        tag1.name,
        tag1.description,
        "Shows: #{tag1.shows.count}",
        "Tracks: #{tag1.tracks.count}"
      )
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag1.shows.count)

    # Click Shows button
    click_on("Tracks: #{tag1.tracks.count}")

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag1.tracks.count)

    # Click first track
    first('ul.item_list li a').click
    expect(page).to have_current_path(/\d{4}-\d{2}-\d{2}/)
  end
end
