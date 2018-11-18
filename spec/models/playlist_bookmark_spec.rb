# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PlaylistBookmark do
  subject { described_class.new }

  it { is_expected.to belong_to(:playlist) }
  it { is_expected.to belong_to(:user) }
end
