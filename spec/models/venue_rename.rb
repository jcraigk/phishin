# frozen_string_literal: true
require 'rails_helper'

RSpec.describe VenueRename do
  subject { build(:venue_rename) }

  it { is_expected.to belong_to(:venue) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:renamed_at) }
end
