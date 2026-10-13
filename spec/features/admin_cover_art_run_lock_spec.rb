require "rails_helper"

RSpec.describe "Admin cover art run lock", :js do
  let(:admin) { create(:user, :admin) }
  let(:kickoff) { create(:show, date: "2025-07-31", published: false) }

  before do
    show = create(:show, date: "2025-08-01", published: false, cover_art_parent_show_id: kickoff.id)
    show.cover_art.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/cover-art-large.jpg")),
      filename: "art.jpg",
      content_type: "image/jpeg"
    )
    sign_in_via_jwt(admin)
    visit "/admin/shows/2025-08-01"
    click_on "Art"
  end

  it "hides the art controls on a show in a run" do
    expect(page).to have_no_css("button[aria-label='New image from a prompt']")
  end

  it "shows the run's current cover art" do
    expect(page).to have_css("img[alt='Current cover art']")
  end

  it "links to the run's kickoff show" do
    expect(page).to have_link(href: "/admin/shows/2025-07-31")
  end

  it "opens the kickoff show's art editor from the link" do
    click_link(href: "/admin/shows/2025-07-31")
    expect(page).to have_css("button[aria-label='New image from a prompt']")
  end
end
