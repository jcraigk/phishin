require "rails_helper"

RSpec.describe "My Shows", :js do
  let(:user) { create(:user) }
  let(:venue) { create(:venue) }
  let(:shows) { create_list(:show, 3, venue:) }

  before do
    shows.each_with_index do |show, idx|
      create(:like, likable: show, user:)
      show.update(duration: show.duration + (idx * 10))
      create_list(:like, (shows.size - idx), likable: show)
    end

    sign_in(user)
  end

  it "displays and sorts shows by default" do
    visit "/my-shows"
    expect(page).to have_current_path("/my-shows")
    expect(page).to have_content("My Shows")
    shows.sort_by(&:date).reverse.each_with_index do |show, idx|
      expect(page).to have_content(show.date.strftime("%b %-d, %Y"))
      expect(page).to have_content(show.venue_name)
    end
  end

  it "allows sorting by likes count" do
    visit "/my-shows"
    select "Sort by Likes (High to Low)", from: "sort"
    sorted_shows = shows.sort_by { |show| show.likes.count }.reverse
    sorted_shows.each_with_index do |show, idx|
      expect(page).to have_content(show.date.strftime("%b %-d, %Y"))
      expect(page).to have_content(show.venue_name)
    end
  end

  context "with more shows" do
    let(:shows) { create_list(:show, 13, venue:) }

    it "paginates shows" do
      visit "/my-shows"
      expect(page).to have_css(".pagination")
      find(".pagination li", text: "2").click
      expect(page).to have_current_path(/\/my-shows.*page=2/)
      expect(page).to have_css(".list-item", count: 3)
    end
  end
end
