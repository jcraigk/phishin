# frozen_string_literal: true
require 'rails_helper'
require 'capybara/email/rspec'

feature 'Reset Password', :js do
  given(:password) { 'Tr3yIsj3dI' }
  given(:new_password) { 'Tr3yIsj3dI2' }
  given(:user) { create(:user, password: password, password_confirmation: password) }

  scenario 'user enters email, receives message, and changes password' do
    visit new_user_session_path

    click_link('Forgot your password?')

    # Enter email address
    fill_in('user[email]', with: user.email)
    click_button('SEND PASSWORD RESET INSTRUCTIONS')
    expect_content('You will receive an email with instructions about how to reset your password shortly')

    # Open the email, click link
    open_email(user.email)
    current_email.find('a').click
    expect(current_path).to eq(edit_user_password_path)

    # User enters a new password, twice
    fill_in('user[password]', with: new_password)
    fill_in('user[password_confirmation]', with: new_password)
    click_on('Change My Password')

    # User's password is changed
    expect(user.reload.valid_password?(new_password)).to eq(true)

    # User is signed in and redirected to root path
    expect(current_path).to eq(root_path)
    expect(page).to have_content('Your password has been changed successfully. You are now signed in.')
  end
end
