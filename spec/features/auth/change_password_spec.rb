require 'rails_helper'

describe 'Change Password', :js do
  let(:password) { 'Tr3yIsj3dI' }
  let(:user) { create(:user, password:, password_confirmation: password) }

  before { login_as(user) }

  it 'click Change Password from user dropdown' do
    visit root_path

    find_by_id('user_controls').click
    click_on('Change Password')

    expect(page).to have_current_path(edit_user_registration_path)
  end

  context 'with invalid data' do
    let(:new_password) { 'new' }

    it 'errors are displayed, password is not changed' do
      visit edit_user_registration_path

      fill_in('user[password]', with: new_password)
      fill_in('user[password_confirmation]', with: 'newpass2')
      fill_in('user[current_password]', with: 'newpass')
      click_on('CHANGE PASSWORD')

      expect_content(
        '3 errors prohibited this user from being saved:',
        'Password confirmation doesn\'t match Password',
        'Password is too short (minimum is 8 characters)',
        'Current password is invalid'
      )
      expect(user.reload.valid_password?(new_password)).to be(false)
    end
  end

  context 'with valid data' do
    let(:new_password) { 'newpassword' }

    it 'errors are displayed, password is not changed' do
      visit edit_user_registration_path

      fill_in('user[password]', with: new_password)
      fill_in('user[password_confirmation]', with: new_password)
      fill_in('user[current_password]', with: password)
      click_on('CHANGE PASSWORD')

      expect_content('You updated your account successfully')
      expect(user.reload.valid_password?(new_password)).to be(true)
    end
  end
end
