# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SearchService do
  subject(:service) { described_class.new(term) }

  let(:term) { nil }

  shared_examples 'expected results' do
    it 'returns expected results' do
      expect(service.call).to eq(expected_results)
    end
  end

  context 'with invalid term' do
    let(:term) { 'a' }

    it 'returns empty hash' do
      expect(service.call).to eq(nil)
    end
  end

  context 'with date-based term' do
    let(:term) { '1995-10-31' }
    let(:date) { Date.parse(term) }
    let(:expected_results) do
      {
        exact_show: show1,
        other_shows: [show2, show3],
        songs: [],
        venues: [],
        tours: [],
        tags: [],
        show_tags: [],
        track_tags: []
      }
    end
    let!(:show1) { create(:show, date: date) }
    let!(:show2) { create(:show, date: date - 1.year) }
    let!(:show3) { create(:show, date: date - 2.years) }
    let!(:show4) { create(:show, date: date - 1.day) }

    include_examples 'expected results'
  end

  context 'with text-based term' do
    let(:term) { 'hood' }
    let(:expected_results) do
      {
        exact_show: nil,
        other_shows: [],
        songs: [song1, song2],
        venues: [venue1, venue3],
        tours: [tour3, tour1],
        tags: [tag2, tag1],
        show_tags: [],
        track_tags: []
      }
    end
    let!(:tag1) { create(:tag, name: 'Hood Tag') }
    let!(:tag2) { create(:tag, name: 'All Hood') }
    let!(:tag3) { create(:tag, name: 'Something Else') }
    let!(:song1) { create(:song, title: 'Harry Hood') }
    let!(:song2) { create(:song, title: 'Hoodenstein') }
    let!(:song3) { create(:song, title: 'Bathtub Gin') }
    let!(:venue1) { create(:venue, name: 'Hood\'s Place') }
    let!(:venue2) { create(:venue, name: 'Nectar\'s') }
    let!(:venue3) { create(:venue, name: 'Hoody') }
    let!(:tour1) { create(:tour, name: 'Hood Tour') }
    let!(:tour2) { create(:tour, name: '1995 Summer Tour') }
    let!(:tour3) { create(:tour, name: 'Another Hood Tour') }

    include_examples 'expected results'
  end
end
