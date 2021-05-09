# frozen_string_literal: true
require 'rails_helper'

describe 'Year spec', :js do
  let(:shows) { create_list(:show, 3) }

  before do
    shows.each_with_index do |show, idx|
      show.update(
        duration: show.duration + idx * 10,
        date: "2018-01-#{idx + 1}"
      )
      create_list(:like, 10 - idx, likable: show)
    end
  end

  it 'visit Year path; sorting, liking' do
    visit '/2018'

    within('#title_box') do
      expect_content('Total shows: 3')
    end

    expect_show_sorting_controls(shows)
  end
end
