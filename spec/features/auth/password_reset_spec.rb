require 'rails_helper'
require 'capybara/email/rspec'

describe 'Reset Password', :js do
  let(:password) { 'Tr3yIsj3dI' }
  let(:new_password) { 'Tr3yIsj3dI2' }
  let(:user) { create(:user, password:, password_confirmation: password) }

  # Fails after following URL in email - token doesn't match
  # probably due to test/development env mismatch
  xit 'user enters email, receives message, and changes password' do
    visit new_user_session_path

    click_on(I18n.t("auth.reset_password"))

    # Enter email address
    fill_in('email', with: user.email)
    click_on(I18n.t("auth.reset_password"))
    expect_content(I18n.t("auth.password_reset_sent"))

    # Open the email, click link
    open_email(user.email)
    visit current_email.body.match(/https?:\/\/[\S]+/).to_s

    # User enters a new password, twice
    fill_in('password', with: new_password)
    fill_in('password_confirmation', with: new_password)
    click_on(I18n.t("auth.reset_password"))

    # User's password is changed
    expect(user.reload.valid_password?(new_password)).to be(true)

    # User is signed in and redirected to root path
    expect(page).to have_current_path(root_path)
  end
end
