# frozen_string_literal: true
require 'rails_helper'

describe 'My Shows', :js do
  let(:user) { create(:user) }
  let(:shows) { create_list(:show, 3) }

  before do
    shows.each_with_index do |show, idx|
      create(:like, likable: show, user:)
      show.update(duration: show.duration + (idx * 10))
      create_list(:like, 10 - idx, likable: show)
    end

    login_as(user)
  end

  it 'click My Shows, display/sorting of shows' do
    visit root_path

    find_by_id('user_controls').click
    click_link('My Shows')

    expect(page).to have_current_path(my_shows_path)

    expect_show_sorting_controls(shows)
  end
end
