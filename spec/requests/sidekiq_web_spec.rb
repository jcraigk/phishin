require "rails_helper"

RSpec.describe "Sidekiq web UI" do
  let(:admin) { create(:user, :admin) }

  it "opens for an admin with a valid cookie" do
    cookies[SidekiqAdminConstraint::COOKIE] = SidekiqAdminConstraint.token_for(admin)

    get "/sidekiq"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sidekiq")
  end

  it "is not found without a cookie" do
    get "/sidekiq"

    expect(response).to have_http_status(:not_found)
  end

  it "is not found with a tampered cookie" do
    cookies[SidekiqAdminConstraint::COOKIE] = "#{SidekiqAdminConstraint.token_for(admin)}x"

    get "/sidekiq"

    expect(response).to have_http_status(:not_found)
  end

  it "is not found once the user loses admin" do
    cookies[SidekiqAdminConstraint::COOKIE] = SidekiqAdminConstraint.token_for(admin)
    admin.update!(admin: false)

    get "/sidekiq"

    expect(response).to have_http_status(:not_found)
  end

  it "is not found once the cookie expires" do
    cookies[SidekiqAdminConstraint::COOKIE] = SidekiqAdminConstraint.token_for(admin)

    travel_to(SidekiqAdminConstraint::TTL.from_now + 1.minute) { get "/sidekiq" }

    expect(response).to have_http_status(:not_found)
  end
end
