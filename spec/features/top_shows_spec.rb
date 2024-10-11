require "rails_helper"

RSpec.describe "Top Shows", :js do
  let!(:shows) { create_list(:show, 3) }

  before do
    shows.each_with_index do |show, idx|
      create_list(:like, shows.size - idx, likable: show)
    end
  end

  it "displays the list of top shows with numbering and links" do
    visit "/top-shows"

    expect(page).to have_css(".sidebar-title", text: "Top 46 Shows")

    shows.sort_by { |show| show.likes.count }.reverse.each_with_index do |show, idx|
      within all(".list-item")[idx] do
        expect(page).to have_css(".leftside-primary", text: show.date.strftime("%b %-d, %Y"))
        expect(page).to have_css(".leftside-secondary", text: show.venue_name)
        within(".like-container") do
          expect(page).to have_content(show.likes_count)
        end
        expect(page).to have_css(".leftside-numbering", text: "##{idx + 1}")
      end
    end

    first(".list-item").click
    expect(page).to have_current_path("/#{shows.first.date}")
  end
end
