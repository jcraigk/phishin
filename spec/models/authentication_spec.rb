require 'rails_helper'

RSpec.describe Authentication do
  subject(:authentication) { build(:authentication) }

  it { is_expected.to be_a(ApplicationRecord) }

  it { is_expected.to belong_to(:user) }
end
