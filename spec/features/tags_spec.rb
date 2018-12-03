# frozen_string_literal: true
require 'rails_helper'

feature 'Tags', :js do
  given(:tag_names) { %w[Awesome Boppin Cool]}
  given!(:tags) do
    tag_names.each_with_object([]) do |name, tags|
      tags << create(:tag, :with_tracks, :with_shows, name: name)
    end
  end
  given(:tag1) { tags.first }
  given(:tag2) { tags.second }
  given(:tag3) { tags.third }

  before do
    create_list(:show, 2, tags: [tag1])
    create_list(:show, 3, tags: [tag2])
    create_list(:track, 5, tags: [tag1])
    create_list(:track, 7, tags: [tag3])
  end

  scenario 'visit Tags page, select a show' do
    visit tags_path

    within('#title_box') do
      expect_content("All Tags (#{tags.count} total)")
    end

    within('#content_box') do
      expect_content(*tags.map(&:name))
      expect_content('2 shows')
      expect_content('2 tracks')
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tags.count)

    click_link(tag1.name)

    within('#title_box') do
      expect_content(tag1.name, tag1.description, "Shows: #{tag1.shows.count}", "Tracks: #{tag1.tracks.count}")
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag1.tracks.count)

    # Click Shows button
    click_button("Shows: #{tag1.shows.count}")

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag1.shows.count)

    # Click first show date
    first('ul.item_list li a').click
    expect(page.current_path).to match(/\d{4}-\d{2}-\d{2}/)
  end

  scenario 'Tag sorting' do
    visit tags_path

    # Default sort by Name
    within('#title_box') do
      expect_content('Sort by', 'Name')
    end
    expect(tag1.name).to appear_before(tag2.name)
    expect(tag2.name).to appear_before(tag3.name)

    # Sort by Track Count
    within('#title_box') do
      first('.btn-group').click
      click_link('Track Count')
      expect_content('Sort by', 'Track Count')
    end
    expect(tag3.name).to appear_before(tag1.name)
    expect(tag1.name).to appear_before(tag2.name)

    # Sort by Show Count
    within('#title_box') do
      first('.btn-group').click
      click_link('Show Count')
      expect_content('Sort by', 'Show Count')
    end
    expect(tag2.name).to appear_before(tag1.name)
    expect(tag1.name).to appear_before(tag3.name)
  end
end
