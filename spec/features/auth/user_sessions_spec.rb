require "rails_helper"

describe "User Sessions", :js do
  let(:username) { "harryhood420" }
  let(:email) { "email@example.com" }
  let(:password) { "Tr3yIsj3dI" }

  before do
    create(
      :user,
      username:,
      email:,
      password:,
      password_confirmation: password
    )
  end

  context "with valid data" do
    it "user signs in" do
      visit "/"

      click_on("LOGIN")

      fill_in("email", with: email)
      fill_in("password", with: password)
      click_on("Login")

      expect(page).to have_current_path("/")
      expect(page).to have_content("Login successful")

      click_on(username)
      find_by_id("logout").click
      expect(page).to have_content("Logged out successfully")
    end
  end

  context "with invalid data" do
    it "user signs up with valid data" do
      visit "/login"

      fill_in("email", with: email)
      fill_in("password", with: "wrongpass")
      click_on("Login")

      expect(page).to have_current_path("/login")
      expect(page).to have_content("Invalid email or password")
    end
  end
end
