# frozen_string_literal: true
require 'rails_helper'

describe User do
  subject { User.new }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:playlists) }
  it { is_expected.to have_many(:playlist_bookmarks) }
  it { is_expected.to have_many(:likes) }

  it { is_expected.not_to allow_value('').for(:username) }
  it { is_expected.not_to allow_value('email@example.com').for(:username) }
  it { is_expected.not_to allow_value('thisusernameistoolong').for(:username) }
  it { is_expected.to allow_value('emailexamplecom').for(:username) }
end
