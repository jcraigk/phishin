# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Like do
  subject { build(:like) }

  it { is_expected.to belong_to(:likable) }
  it { is_expected.to belong_to(:user) }
end
