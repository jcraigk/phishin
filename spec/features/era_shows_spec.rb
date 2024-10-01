require "rails_helper"

RSpec.describe "Era Shows", :js do
  let(:venue) { create(:venue) }
  let(:shows) do
    [
      create(:show, venue:, date: "2024-01-01"),
      create(:show, venue:, date: "2024-02-01"),
      create(:show, venue:, date: "2024-03-01"),
      create(:show, venue:, date: "2024-04-01"),
      create(:show, venue:, date: "2024-05-01")
    ]
  end

  before do
    shows.each_with_index do |show, idx|
      create(:like, likable: show)
      show.update(duration: show.duration + (idx * 10))
    end
  end

  it "displays the correct year and shows count in the sidebar" do
    visit "/2024"

    expect(page).to have_css(".sidebar-title", text: "2024")
    expect(page).to have_css(".sidebar-subtitle", text: "5 shows")
  end

  it "displays the list of shows with correct data" do
    visit "/2024"

    shows.each do |show|
      expect(page).to have_content(show.date.to_s.gsub("-", "."))
      expect(page).to have_content(show.venue.name)
    end
  end

  it "displays the tour headers if present" do
    visit "/2024"

    # Assuming each show belongs to a tour with a tour name
    shows.each do |show|
      expect(page).to have_content(show.tour.name)
    end
  end
end
