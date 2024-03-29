require 'rails_helper'

RSpec.describe TrackTag do
  subject { build(:track_tag) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:track).counter_cache(:tags_count) }
  it { is_expected.to belong_to(:tag).counter_cache(:tracks_count) }
end
