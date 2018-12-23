# frozen_string_literal: true
require 'rails_helper'

RSpec.describe TrackInserter do
  subject(:service) { described_class.new(opts) }

  let(:opts) do
    {
      date: date,
      position: 2,
      file: file,
      title: title,
      song_id: song_id,
      set: 1,
      is_sbd: true
    }
  end
  let(:show) { create(:show) }
  let!(:track1) { create(:track, show: show, position: 1) }
  let!(:track2) { create(:track, show: show, position: 2) }
  let!(:track3) { create(:track, show: show, position: 3) }
  let(:song) { create(:song) }
  let(:file) { "#{Rails.root}/spec/fixtures/test.mp3" }
  let(:date) { show.date }
  let(:song_id) { song.id }
  let(:title) { 'New Track' }

  context 'with invalid options' do
    let(:opts) { { invalid: 'options' } }

    it 'raises exception' do
      expect { service.call }.to raise_error(RuntimeError, 'Invalid options!')
    end
  end

  context 'with valid options' do
    context 'when file does not exist' do
      let(:file) { '/nonexistent/file' }

      it 'raises exception' do
        expect { service.call }.to raise_error(RuntimeError, 'Invalid file!')
      end
    end

    context 'when song does not exist' do
      let(:song_id) { 999_999 }

      it 'raises exception' do
        expect { service.call }.to raise_error(RuntimeError, 'Invalid song!')
      end
    end

    context 'when show does not exist' do
      let(:date) { '1885-12-21' }

      it 'raises exception' do
        expect { service.call }.to raise_error(RuntimeError, 'Invalid show!')
      end
    end

    context 'when entities exist' do
      let!(:sbd_tag) { create(:tag, name: 'SBD') }

      it 'inserts the track, shifting other tracks up' do
        service.call
        show.reload
        expect(show.tracks.size).to eq(4)
        new_track = show.tracks.sort_by(&:position).second
        expect(new_track.title).to eq(title)
        expect(new_track.tags).to include(sbd_tag)
      end
    end
  end
end
