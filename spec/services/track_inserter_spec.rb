# frozen_string_literal: true
require 'rails_helper'

RSpec.describe TrackInserter do
  subject(:service) { described_class.new(opts) }

  let(:opts) do
    {
      date:,
      position: 2,
      file:,
      title:,
      song_id:,
      set: 1,
      is_sbd: true
    }
  end
  let(:date) { show.date }
  let(:file) { Rails.root.join('spec/fixtures/audio_file.mp3') }
  let(:show) { create(:show) }
  let(:song_id) { song.id }
  let(:song) { create(:song) }
  let(:title) { 'New Track' }
  let(:mock_generator) { instance_spy(WaveformImageGenerator) }

  before do
    allow(WaveformImageGenerator).to receive(:new).and_return(mock_generator)
    allow(mock_generator).to receive(:call)

    create(:track, show:, position: 1)
    create(:track, show:, position: 2)
    create(:track, show:, position: 3)
  end

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
      let(:new_track) { show.tracks.sort_by(&:position).second }

      before do
        service.call
        show.reload
      end

      it 'inserts the track' do
        expect(new_track.title).to eq(title)
      end

      it 'includes SBD tag' do
        expect(new_track.tags).to include(sbd_tag)
      end
    end
  end
end
