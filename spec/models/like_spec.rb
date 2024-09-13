require 'rails_helper'

RSpec.describe Like do
  subject { build(:like) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:likable) }
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    subject { create(:like) }  # Create an actual record in the database

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(%i[likable_id likable_type]) }
  end
end
