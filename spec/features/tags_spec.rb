require "rails_helper"

RSpec.describe "Tags", :js do
  let!(:show) { create(:show, tags: [ tag1, tag2 ]) }
  let!(:track) { create(:track, tags: [ tag1, tag2 ]) }
  let(:group1) { "Group 1" }
  let(:group2) { "Group 2" }
  let(:tag1) { create(:tag, name: "Tag 1", group: group1, shows_count: 1, tracks_count: 1) }
  let(:tag2) { create(:tag, name: "Tag 2", group: group1, shows_count: 1, tracks_count: 1) }
  let(:tag3) { create(:tag, name: "Tag 3", group: group2, shows_count: 1, tracks_count: 0) }
  let(:show2) { create(:show, tags: [ tag3 ]) }

  before { show2 }

  it "displays grouped tags with correct counts and links" do
    visit "/tags"

    expect(page).to have_css(".section-title", text: "Group 1")
    expect(page).to have_css(".section-title", text: "Group 2")

    within first(".list-item", text: tag1.name) do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag1.slug}")
      expect(page).to have_link("2 tracks", href: "/track-tags/#{tag1.slug}")
    end

    within all(".list-item")[1] do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag2.slug}")
      expect(page).to have_link("2 tracks", href: "/track-tags/#{tag2.slug}")
    end

    within first(".list-item", text: tag3.name) do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag3.slug}")
      expect(page).to have_link("0 tracks", href: "/track-tags/#{tag3.slug}")
    end
  end

  it "navigates to show tag page and displays correct show count" do
    visit "/tags"

    first(".list-item", text: tag1.name).find("a", text: "2 shows").click
    expect(page).to have_current_path("/show-tags/#{tag1.slug}")
    expect(page).to have_css(".list-item", text: show.date.strftime("%b %-d, %Y"))
  end

  it "navigates to track tag page and displays correct track count" do
    visit "/tags"

    first(".list-item", text: tag1.name).find("a", text: "2 tracks").click
    expect(page).to have_current_path("/track-tags/#{tag1.slug}")
    expect(page).to have_css(".list-item", text: track.title)
  end
end
