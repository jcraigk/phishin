require "rails_helper"

describe "User Registration", :js do
  let(:password) { "Tr3yIsj3dI" }
  let(:email) { "email@example.com" }
  let(:username) { "harryhood" }

  context "with valid data" do
    it "user signs up" do
      visit root_path

      click_on("Sign in")
      click_on("Create New Account")

      fill_in("user[username]", with: username)
      fill_in("user[email]", with: email)
      fill_in("user[password]", with: password)
      fill_in("user[password_confirmation]", with: password)
      click_on("Create New Account")

      expect(page).to have_current_path(root_path)
      expect_content(I18n.t("auth.signup_success"))
    end
  end

  context "with invalid data" do
    it "user attempts signup but gives unmatched passwords" do
      visit new_user_path

      fill_in("user[username]", with: username)
      fill_in("user[email]", with: email)
      fill_in("user[password]", with: password)
      fill_in("user[password_confirmation]", with: "b")
      click_on("Create New Account")

      expect(page).to have_current_path(new_user_path)
      expect_content(I18n.t("auth.passwords_dont_match"))
    end

    it "user attempts signup but gives bad username" do
      visit new_user_path

      fill_in("user[username]", with: "#{username}&*")
      fill_in("user[email]", with: email)
      fill_in("user[password]", with: password)
      fill_in("user[password_confirmation]", with: password)
      click_on("Create New Account")

      expect_content \
        "Username may contain only letters, numbers, and underscores, must be unique, and must " \
        "be 4 to 15 characters long"
    end
  end
end
