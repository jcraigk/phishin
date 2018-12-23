# frozen_string_literal: true
require 'rails_helper'

RSpec.describe TrackInserter do
  subject(:service) { described_class.new(date) }

  let(:date) { '1995-10-31' }
  let(:song) { create(:song) }
  let(:opts) do
    {
      date: date,
      position: 2,
      file: "#{Rails.root}/spec/fixtures/test.mp3",
      title: 'New Track',
      song_id: song.id,
      set: 1,
      is_sbd: true
    }
  end

  shared_examples 'successful parse' do
    it 'returns formatted date' do
      expect(service.call).to eq(formatted_date)
    end
  end

  context 'with invalid date' do
    let(:date) { 'blah' }

    it 'returns false' do
      expect(service.call).to eq(false)
    end
  end

  context 'with short date slashed' do
    let(:date) { '10/31/95' }

    include_examples 'successful parse'
  end

  context 'with short date dashed' do
    let(:date) { '10-31-95' }

    include_examples 'successful parse'
  end

  context 'with full year at end slashed' do
    let(:date) { '10/31/1995' }

    include_examples 'successful parse'
  end

  context 'with full year at end dashed' do
    let(:date) { '10-31-1995' }

    include_examples 'successful parse'
  end

  context 'with db formatted date' do
    let(:date) { '1995-10-31' }

    include_examples 'successful parse'
  end
end
