# frozen_string_literal: true
require 'rails_helper'

feature 'User Registration', :js do
  context 'with valid data' do
    given(:username) { 'harryhood420' }
    given(:email) { 'email@example.com' }
    given(:password) { 'Tr3yIsj3dI' }

    scenario 'user signs up' do
      visit root_path

      click_link('Sign in')
      click_link('Sign up now!')

      fill_in('user[username]', with: username)
      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      fill_in('user[password_confirmation]', with: password)
      click_button('SIGN UP')

      expect(page).to have_current_path(root_path)
      expect_content('Welcome! You have signed up successfully')
    end
  end

  context 'with invalid data' do
    given(:username) { 'h' }
    given(:email) { 'email@example.com' }
    given(:password) { 'a' }

    scenario 'user attempts signup' do
      visit new_user_registration_path

      fill_in('user[username]', with: username)
      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      fill_in('user[password_confirmation]', with: 'b')
      click_button('SIGN UP')

      expect(page).to have_current_path('/users')
      expect_content(
        '3 errors prohibited this user from being saved:',
        'Password confirmation doesn\'t match Password',
        'Password is too short (minimum is 8 characters)',
        'Username may contain only letters, numbers, ' \
        'and underscores; must be unique; and must be 4 to 15 characters long'
      )
    end
  end
end
