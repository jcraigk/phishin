require 'rails_helper'

describe 'Play Random Show', :js do
  before { create_list(:show, 2, :with_tracks) }

  it 'click Play button to play random show' do
    visit root_path

    find_by_id('control_playpause').click
    expect_content('Playing random show...')

    expect(page).to have_current_path(/\d{4}-\d{2}-\d{2}/)
  end
end
