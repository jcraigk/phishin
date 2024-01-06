require 'rails_helper'

describe 'User Registration', :js do
  context 'with valid data' do
    let(:username) { 'harryhood420' }
    let(:email) { 'email@example.com' }
    let(:password) { 'Tr3yIsj3dI' }

    it 'user signs up' do
      visit root_path

      click_on('Sign in')
      click_on('Sign up now!')

      fill_in('user[username]', with: username)
      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      fill_in('user[password_confirmation]', with: password)
      click_on('SIGN UP')

      expect(page).to have_current_path(root_path)
      expect_content('Welcome! You have signed up successfully')
    end
  end

  context 'with invalid data' do
    let(:username) { 'h' }
    let(:email) { 'email@example.com' }
    let(:password) { 'a' }

    it 'user attempts signup' do
      visit new_user_registration_path

      fill_in('user[username]', with: username)
      fill_in('user[email]', with: email)
      fill_in('user[password]', with: password)
      fill_in('user[password_confirmation]', with: 'b')
      click_on('SIGN UP')

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
