# frozen_string_literal: true
require 'rails_helper'

describe 'RSS Feed' do
  let!(:announcements) { create_list(:announcement, 2) }

  it 'click My Shows, display/sorting of shows' do
    visit rss_feed_path

    expect(page).to have_content(announcements.first.title)
    expect(page).to have_content(announcements.second.title)
  end
end
