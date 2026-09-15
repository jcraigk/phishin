require "rails_helper"

RSpec.describe "Tooltips", :js do
  let(:tag) { create(:tag, name: "Jamcharts", description: "Recommended by Phish.net Jamcharts") }
  let(:show) { create(:show, date: "2023-08-01") }

  before { create(:track, show:, tags: [ tag ]) }

  it "shows a tag badge tooltip on hover" do
    visit "/2023-08-01"

    find(".tag-badge", text: "Jamcharts").hover
    expect(page).to have_css(".custom-tooltip", text: "Recommended by Phish.net Jamcharts")
  end

  it "shows a related app tooltip on hover" do
    visit "/"

    find("img[alt='Relisten']").hover
    expect(page).to have_css(".custom-tooltip", text: "Relisten (iOS / Android)")
  end

  it "hides the tooltip when the pointer leaves" do
    visit "/"

    find("img[alt='Relisten']").hover
    expect(page).to have_css(".custom-tooltip")
    find_by_id("navbar").hover
    expect(page).to have_no_css(".custom-tooltip")
  end
end
