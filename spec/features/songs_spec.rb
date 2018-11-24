# frozen_string_literal: true
require 'rails_helper'

feature 'Songs', :js do
  given(:songs) { create_list(:song, 30, :with_tracks) }
  given(:a_title) { 'A laska' }
  given(:g_title) { 'G rind' }
  given(:a_title_count) { songs.select { |v| v.title.start_with?('A') }.size }
  given(:g_title_count) { songs.select { |v| v.title.start_with?('G') }.size }

  before do
    songs.first.update(title: a_title)
    songs.second.update(title: g_title)
  end

  scenario 'visit Songs page' do
    visit songs_path

    within('#title_box') do
      expect_content("'A' Songs", "Total Songs: #{a_title_count}")
    end

    within('#sub_nav') do
      expect_content('ABCDEFGHIJKLMNOPQRSTUVWXYZ#')
    end

    within('#content_box') do
      expect_content(a_title)
    end

    # Click on sub nav 'G'
    within('#sub_nav') do
      click_link('G')
    end

    within('#title_box') do
      expect_content("'G' Songs", "Total Songs: #{g_title_count}")
    end

    within('#content_box') do
      expect_content(g_title)
    end

    # Click on first song
    first('ul.item_list li').click
    expect(page).to have_current_path("/#{songs.second.slug}")
  end
end
