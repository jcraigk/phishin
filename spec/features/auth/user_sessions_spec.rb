# frozen_string_literal: true
require 'rails_helper'

describe 'User Sessions', :js do
  let(:username) { 'harryhood420' }
  let(:email) { 'email@example.com' }
  let(:password) { 'Tr3yIsj3dI' }

  before do
    create(:user, username: username, email: email, password: password, password_confirmation: password)
  end

  context 'with valid data' do
    it 'user signs in' do
      visit root_path

      click_link('Sign in')

      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      click_button('SIGN IN')

      expect(page).to have_current_path(root_path)
      expect_content('Signed in successfully')

      find('#user_controls').click
      click_link('Logout')

      expect(page).to have_current_path(root_path)
      expect_content('Signed out successfully')
    end
  end

  context 'with invalid data' do
    it 'user signs up with valid data' do
      visit new_user_session_path

      fill_in('user[email]', with: email)
      fill_in('user[password]', with: 'wrongpass')
      click_button('SIGN IN')

      expect(page).to have_current_path(new_user_session_path)
      expect_content('Invalid email or password')
    end
  end
end
