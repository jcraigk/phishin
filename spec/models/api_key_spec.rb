# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  subject(:api_key) { build(:api_key) }

  it { is_expected.to be_an(ApplicationRecord) }
  it { is_expected.to have_many(:api_requests) }

  describe 'attributes' do
    subject(:api_key) { described_class.attribute_names.map(&:to_sym) }

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
      subject(:api_key) { described_class.active }

      it 'returns active keys' do
        expect(api_key).to include active_key
        expect(api_key).not_to include revoked_key
      end
    end

    describe '.not_revoked' do
      subject(:api_key) { described_class.not_revoked }

      it 'returns only not revoked keys' do
        expect(api_key).to include active_key
        expect(api_key).not_to include revoked_key
      end
    end

    describe '.revoked' do
      subject(:api_key) { described_class.revoked }

      it 'returns only revoked keys' do
        expect(api_key).not_to include active_key
        expect(api_key).to include revoked_key
      end
    end
  end

  it 'generates a key on create' do
    expect(create(:api_key).key).to be_present
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
      before { allow(api_key).to receive(:revoked_at).and_return Time.current }

      it 'returns true' do
        expect(api_key).to be_revoked
      end
    end

    context 'when not revoked' do
      before { allow(api_key).to receive(:revoked_at).and_return nil }

      it 'returns false' do
        expect(api_key).not_to be_revoked
      end
    end
  end
end
