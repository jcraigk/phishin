# frozen_string_literal: true
require 'rails_helper'

feature 'User Sessions', :js do
  given(:username) { 'harryhood420' }
  given(:email) { 'email@example.com' }
  given(:password) { 'Tr3yIsj3dI' }
  given!(:user) do
    create(:user, username: username, email: email, password: password, password_confirmation: password)
  end

  context 'with valid data' do
    scenario 'user signs in' do
      visit root_path

      click_link('Sign in')

      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      click_button('SIGN IN')

      expect(page).to have_current_path(root_path)
      expect_content('Signed in successfully')
    end
  end

  context 'with invalid data' do
    scenario 'user signs up with valid data' do
      visit new_user_session_path

      fill_in('user[email]', with: email)
      fill_in('user[password]', with: 'wrongpass')
      click_button('SIGN IN')

      expect(page).to have_current_path(new_user_session_path)
      expect_content('Invalid email or password')
    end
  end
end
