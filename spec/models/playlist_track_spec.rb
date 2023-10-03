require 'rails_helper'

RSpec.describe PlaylistTrack do
  subject { build(:playlist_track) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:playlist) }
  it { is_expected.to belong_to(:track) }

  it { is_expected.to validate_numericality_of(:position).only_integer }
  it { is_expected.to validate_uniqueness_of(:position).scoped_to(:playlist_id) }
end
