require "rails_helper"

describe "User Registration", :js do
  let(:password) { "Tr3yIsj3dI" }
  let(:email) { "email@example.com" }
  let(:username) { "harryhood" }

  context "with valid data" do
    it "user signs up" do
      visit '/'

      # save_and_open_page
      click_on("LOGIN")
      click_on("Sign Up")

      fill_in("username", with: username)
      fill_in("email", with: email)
      fill_in("password", with: password)
      fill_in("passwordConfirmation", with: password)
      click_on("Sign Up")

      expect(page).to have_current_path('/')
      expect(page).to have_content("User created successfully - you are now logged in")
    end
  end

  context "with invalid data" do
    it "user attempts signup but gives unmatched passwords" do
      visit ('/signup')

      fill_in("username", with: username)
      fill_in("email", with: email)
      fill_in("password", with: password)
      fill_in("passwordConfirmation", with: 'b')
      click_on("Sign Up")

      expect(page).to have_current_path('/signup')
      expect(page).to have_content("Passwords do not match")
    end

    it "user attempts signup but gives bad username" do
      visit ('/signup')

      fill_in("username", with: "#{username}&*")
      fill_in("email", with: email)
      fill_in("password", with: password)
      fill_in("passwordConfirmation", with: password)
      click_on("Sign Up")

      expect(page).to have_content \
        "Username may contain only letters, numbers, and underscores, " \
        "must be unique, and must be 4 to 15 characters long"
    end
  end
end
