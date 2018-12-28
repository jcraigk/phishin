# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  subject { build(:api_key) }

  it { is_expected.to be_an(ApplicationRecord) }
  it { is_expected.to have_many(:api_requests) }

  describe 'attributes' do
    subject { described_class.attribute_names.map(&:to_sym) }
    it { is_expected.to include :id }
    it { is_expected.to include :name }
    it { is_expected.to include :email }
    it { is_expected.to include :key }
    it { is_expected.to include :created_at }
    it { is_expected.to include :updated_at }
    it { is_expected.to include :revoked_at }
  end

  describe 'scopes' do
    let!(:active_key) { create(:api_key) }
    let!(:revoked_key) { create(:api_key, :revoked) }

    describe '.active' do
      subject { described_class.active }

      it 'returns active keys' do
        expect(subject).to include active_key
        expect(subject).not_to include revoked_key
      end
    end

    describe '.not_revoked' do
      subject { described_class.not_revoked }

      it 'returns only not revoked keys' do
        expect(subject).to include active_key
        expect(subject).not_to include revoked_key
      end
    end

    describe '.revoked' do
      subject { described_class.revoked }

      it 'returns only revoked keys' do
        expect(subject).not_to include active_key
        expect(subject).to include revoked_key
      end
    end
  end

  context 'callbacks' do
    context 'before create' do
      it 'generates a key' do
        expect(create(:api_key).key).to be_present
      end
    end
  end

  describe '#revoke!' do
    it 'revokes the key' do
      key = create(:api_key)
      expect(key).not_to be_revoked
      key.revoke!
      expect(key).to be_revoked
    end
  end

  describe '#revoked?' do
    context 'when revoked' do
      before { allow(subject).to receive(:revoked_at).and_return Time.current }

      it 'returns true' do
        expect(subject).to be_revoked
      end
    end

    context 'when not revoked' do
      before { allow(subject).to receive(:revoked_at).and_return nil }

      it 'returns false' do
        expect(subject).not_to be_revoked
      end
    end
  end
end
