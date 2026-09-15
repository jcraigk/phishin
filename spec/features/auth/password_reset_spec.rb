require "rails_helper"
require "capybara/email/rspec"

describe "Reset Password", :enable_sidekiq, :js do
  let(:password) { "Tr3yIsj3dI" }
  let(:new_password) { "Tr3yIsj3dI2" }
  let(:user) { create(:user, password:, password_confirmation: password) }

  it "user enters email, receives message, and changes password" do
    visit "/login"

    click_on("Forgot your password?")
    fill_in("email", with: user.email)
    click_on("Request password reset")
    expect(page).to have_text \
      "Password reset instructions will be sent to the email if it exists"

    open_email(user.email)
    expect(current_email.subject).to eq("Reset Password")
    reset_url = current_email.body.match(%r{https?://\S+})[0]
    expect(reset_url).to end_with("/reset-password/#{user.reload.reset_password_token}")
    visit URI.parse(reset_url).path

    fill_in("password", with: new_password)
    fill_in("passwordConfirmation", with: new_password)
    click_on("Reset password")
    expect(page).to have_text("Password reset successfully")

    expect(user.reload.valid_password?(new_password)).to be(true)
  end
end
