require "rails_helper"

RSpec.describe "Not found page", :js do
  it "renders inside the site layout" do
    visit "/no-such-page"

    expect(page).to have_css(".error-title", text: "404")
    expect(page).to have_css("#navbar")
  end
end
