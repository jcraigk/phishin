require "rails_helper"

RSpec.describe "Admin pages" do
  it "serves the show editor path through the React harness" do
    get "/admin/shows/2024-07-19"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="root"')
  end

  it "serves the import page with an ok status" do
    get "/admin/import"
    expect(response).to have_http_status(:ok)
  end
end
