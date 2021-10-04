# frozen_string_literal: true
require 'rails_helper'

RSpec.describe TrackSlugGenerator do
  subject(:service) { described_class.new(track) }

  let(:show) { create(:show) }
  let(:track) { build(:track, show: show, title: title) }
  let(:title) { "I Didn't Know" }

  context 'when title is not a specific long name' do
    before do
      create(:track, show: show, title: title, slug: 'i-didnt-know')
      create(:track, show: show, title: title, slug: 'i-didnt-know-2')
      create(:track, show: show, title: 'Bathtub Gin', slug: 'bathtub-gin')
      create(:track, show: show, title: 'Prince Caspian', slug: 'prince-caspian')
    end

    it 'returns a unique slug with expected suffix' do
      expect(service.call).to eq('i-didnt-know-3')
    end
  end

  context 'when title is Hold Your Head Up' do
    let(:title) { 'Hold Your Head Up' }

    it 'returns an abbreviated slug' do
      expect(service.call).to eq('hyhu')
    end
  end

  context 'when title is The Man Who Stepped Into Yesterday' do
    let(:title) { 'The Man Who Stepped Into Yesterday' }

    it 'returns an abbreviated slug' do
      expect(service.call).to eq('tmwsiy')
    end
  end

  context 'when title is She Caught the Katy and Left Me a Mule to Ride' do
    let(:title) { 'She Caught the Katy and Left Me a Mule to Ride' }

    it 'returns an abbreviated slug' do
      expect(service.call).to eq('she-caught-the-katy')
    end
  end

  context 'when title is McGrupp and the Watchful Hosemasters' do
    let(:title) { 'McGrupp and the Watchful Hosemasters' }

    it 'returns an abbreviated slug' do
      expect(service.call).to eq('mcgrupp')
    end
  end

  context 'when title is Big Black Furry Creature from Mars' do
    let(:title) { 'Big Black Furry Creature from Mars' }

    it 'returns an abbreviated slug' do
      expect(service.call).to eq('bbfcfm')
    end
  end
end
