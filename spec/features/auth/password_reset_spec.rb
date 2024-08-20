require 'rails_helper'
require 'capybara/email/rspec'

describe 'Reset Password', :js do
  let(:password) { 'Tr3yIsj3dI' }
  let(:new_password) { 'Tr3yIsj3dI2' }
  let(:user) { create(:user, password:, password_confirmation: password) }

  xit 'user enters email, receives message, and changes password' do
    visit new_user_session_path

    click_on('Reset password')

    # Enter email address
    fill_in('user[email]', with: user.email)
    click_on('SEND PASSWORD RESET INSTRUCTIONS')
    expect_content(
      'You will receive an email with instructions about how to reset your password shortly'
    )

    # Open the email, click link
    open_email(user.email)
    current_email.find('a').click
    expect(page).to have_current_path(edit_user_password_path)

    # User enters a new password, twice
    fill_in('user[password]', with: new_password)
    fill_in('user[password_confirmation]', with: new_password)
    click_on('Change My Password')

    # User's password is changed
    expect(user.reload.valid_password?(new_password)).to be(true)

    # User is signed in and redirected to root path
    expect(page).to have_current_path(root_path)
    expect(page).to(
      have_content('Your password has been changed successfully. You are now signed in.')
    )
  end
end
