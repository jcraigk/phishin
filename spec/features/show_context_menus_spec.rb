# frozen_string_literal: true
require 'rails_helper'

describe 'Show Context Menus', :js do
  let(:show) { create(:show, :with_tracks) }
  let(:track) { show.tracks.first }

  it 'use the show dropdown' do
    visit show.date

    first('.show-context-dropdown').click

    expect_content('Lookup at phish.net')

    click_link('Add to playlist')
    expect_content('Tracks added to playlist')

    click_link('Share')
    expect_content('Copypasta...')
    first('.close').click
  end
end
