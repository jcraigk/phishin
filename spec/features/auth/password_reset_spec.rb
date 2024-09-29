require "rails_helper"
require "capybara/email/rspec"

describe "Reset Password", :js do
  let(:password) { "Tr3yIsj3dI" }
  let(:new_password) { "Tr3yIsj3dI2" }
  let(:user) { create(:user, password:, password_confirmation: password) }

  it "user enters email, receives message, and changes password" do
    visit "/login"

    click_on("Forgot your password?")
    fill_in("email", with: user.email)
    click_on("Request password reset")
    expect_content("Password reset instructions will be sent to the email if it exists")

    # Open the email, click link
    # (not working due to config issues, so we skip it)
    # open_email(user.email)
    # visit current_email.body.match(/https?:\/\/[\S]+/).to_s

    visit "/reset-password/#{user.reload.reset_password_token}"

    # User enters a new password, twice
    fill_in("password", with: new_password)
    fill_in("passwordConfirmation", with: new_password)
    click_on("Reset password")
    expect(page).to have_content("Password reset successfully")

    # User's password is changed
    expect(user.reload.valid_password?(new_password)).to be(true)
  end
end
