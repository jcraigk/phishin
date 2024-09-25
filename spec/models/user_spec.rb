require 'rails_helper'

describe User do
  subject { build(:user) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:playlists) }
  it { is_expected.to have_many(:likes) }
end
