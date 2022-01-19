# frozen_string_literal: true
require 'rails_helper'

describe 'Venue page', :js do
  let(:venue) { create(:venue) }
  let(:shows) { create_list(:show, 3, venue:) }

  before do
    shows.each_with_index do |show, idx|
      show.update(duration: show.duration + (idx * 10))
      create_list(:like, 10 - idx, likable: show)
    end
  end

  it 'sorting' do
    visit "/#{venue.slug}"
    expect_content('Total shows: 3')

    expect_show_sorting_controls(shows)
  end
end
