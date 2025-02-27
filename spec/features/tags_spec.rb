require "rails_helper"

RSpec.describe "Tags", :js do
  let!(:show) { create(:show, tags: [ tag_1, tag_2 ]) }
  let!(:track) { create(:track, tags: [ tag_1, tag_2 ]) }
  let(:group_1) { "Group 1" }
  let(:group_2) { "Group 2" }
  let(:tag_1) { create(:tag, name: "Tag 1", group: group_1, shows_count: 1, tracks_count: 1) }
  let(:tag_2) { create(:tag, name: "Tag 2", group: group_1, shows_count: 1, tracks_count: 1) }
  let(:tag_3) { create(:tag, name: "Tag 3", group: group_2, shows_count: 1, tracks_count: 0) }
  let(:show_2) { create(:show, tags: [ tag_3 ]) }

  before { show_2 }

  it "displays grouped tags with correct counts and links" do
    visit "/tags"

    expect(page).to have_css(".section-title", text: "Group 1")
    expect(page).to have_css(".section-title", text: "Group 2")

    within first(".list-item", text: tag_1.name) do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag_1.slug}")
      expect(page).to have_link("2 tracks", href: "/track-tags/#{tag_1.slug}")
    end

    within all(".list-item")[1] do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag_2.slug}")
      expect(page).to have_link("2 tracks", href: "/track-tags/#{tag_2.slug}")
    end

    within first(".list-item", text: tag_3.name) do
      expect(page).to have_link("2 shows", href: "/show-tags/#{tag_3.slug}")
      expect(page).to have_link("0 tracks", href: "/track-tags/#{tag_3.slug}")
    end
  end

  it "navigates to show tag page and displays correct show count" do
    visit "/tags"

    first(".list-item", text: tag_1.name).find("a", text: "2 shows").click
    expect(page).to have_current_path("/show-tags/#{tag_1.slug}")
    expect(page).to have_css(".list-item", text: show.date.strftime("%b %-d, %Y"))
  end

  it "navigates to track tag page and displays correct track count" do
    visit "/tags"

    first(".list-item", text: tag_1.name).find("a", text: "2 tracks").click
    expect(page).to have_current_path("/track-tags/#{tag_1.slug}")
    expect(page).to have_css(".list-item", text: track.title)
  end
end
