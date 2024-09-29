require 'rails_helper'

RSpec.describe 'My Shows Page', :js do
  let(:user) { create(:user) }
  let(:venue) { create(:venue) }
  let(:shows) { create_list(:show, 3, venue:) }

  before do
    shows.each_with_index do |show, idx|
      create(:like, likable: show, user:)
      show.update(duration: show.duration + (idx * 10))
      create_list(:like, 10 - idx, likable: show)
    end

    sign_in(user)
  end

  it 'displays and sorts shows by default' do
    visit '/my-shows'
    expect(page).to have_current_path('/my-shows')
    expect(page).to have_content('My Shows')
    shows.sort_by(&:date).reverse.each_with_index do |show, idx|
      expect(page).to have_content(show.date.strftime("%b %d, %Y"))
      expect(page).to have_content(show.venue.name)
    end
  end

  it 'allows sorting by likes count' do
    visit '/my-shows'
    select 'Sort by Likes (Most to Least)', from: 'sort'
    sorted_shows = shows.sort_by { |show| show.likes.count }.reverse
    sorted_shows.each_with_index do |show, idx|
      expect(page).to have_content(show.date.strftime("%b %d, %Y"))
      expect(page).to have_content(show.venue.name)
    end
  end

  it 'paginates shows' do
    additional_shows = create_list(:show, 10, venue:)
    visit '/my-shows'
    expect(page).to have_selector('.pagination')
    find('.pagination .page-link', text: '2').click
    expect(page).to have_current_path(my_shows_path(page: 2))
    additional_shows.each do |show|
      expect(page).to have_content(show.date.strftime("%b %d, %Y"))
    end
  end
end
