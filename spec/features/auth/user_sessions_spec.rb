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
      visit root_path

      click_on("Sign in")

      fill_in("email", with: email)
      fill_in("password", with: password)
      click_on(I18n.t("auth.login"))

      expect(page).to have_current_path(root_path)
      expect_content(I18n.t("auth.login_success"))

      find_by_id("user_controls").click
      click_on(I18n.t("auth.logout"))

      expect_content(I18n.t("auth.logout_success"))
    end
  end

  context "with invalid data" do
    it "user signs up with valid data" do
      visit new_user_session_path

      fill_in("email", with: email)
      fill_in("password", with: "wrongpass")
      click_on(I18n.t("auth.login"))

      expect(page).to have_current_path(new_user_session_path)
      expect_content(I18n.t("auth.login_fail"))
    end
  end
end
