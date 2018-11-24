# frozen_string_literal: true
require 'rails_helper'

feature 'Change Password', :js do
  given(:password) { 'Tr3yIsj3dI' }
  given(:user) { create(:user, password: password, password_confirmation: password) }

  before { login_as(user) }

  scenario 'click Change Password from user dropdown' do
    visit root_path

    find('#user_controls').click
    click_link('Change Password')

    expect(page).to have_current_path(edit_user_registration_path)
  end

  context 'with invalid data' do
    given(:new_password) { 'new' }

    scenario 'errors are displayed, password is not changed' do
      visit edit_user_registration_path

      fill_in('user[password]', with: new_password)
      fill_in('user[password_confirmation]', with: 'newpass2')
      fill_in('user[current_password]', with: 'newpass')
      click_button('CHANGE PASSWORD')

      expect_content(
        '3 errors prohibited this user from being saved:',
        'Password confirmation doesn\'t match Password',
        'Password is too short (minimum is 8 characters)',
        'Current password is invalid'
      )
      expect(user.reload.valid_password?(new_password)).to eq(false)
    end
  end

  context 'with valid data' do
    given(:new_password) { 'newpassword' }

    scenario 'errors are displayed, password is not changed' do
      visit edit_user_registration_path

      fill_in('user[password]', with: new_password)
      fill_in('user[password_confirmation]', with: new_password)
      fill_in('user[current_password]', with: password)
      click_button('CHANGE PASSWORD')

      expect_content('You updated your account successfully')
      expect(user.reload.valid_password?(new_password)).to eq(true)
    end
  end
end
