# frozen_string_literal: true
require 'rails_helper'

feature 'Tags', :js do
  given!(:tags) { create_list(:tag, 3, :with_tracks, :with_shows) }
  given(:tag) { tags.first }

  scenario 'visit Tags page' do
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

    click_link(tag.name)

    within('#title_box') do
      expect_content(tag.name, tag.description, "Shows: #{tag.shows.count}", "Tracks: #{tag.tracks.count}")
    end

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag.tracks.count)

    click_button("Shows: #{tag.shows.count}")

    items = page.all('ul.item_list li')
    expect(items.count).to eq(tag.shows.count)
  end
end
