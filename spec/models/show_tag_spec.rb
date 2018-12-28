# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ShowTag do
  subject { build(:show_tag) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:show).counter_cache(:tags_count) }
  it { is_expected.to belong_to(:tag).counter_cache(:shows_count) }

  it { is_expected.to validate_uniqueness_of(:show).scoped_to(:tag_id) }
end
