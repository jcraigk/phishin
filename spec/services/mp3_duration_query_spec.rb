# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Mp3DurationQuery do
  subject(:service) { described_class.new(mp3_file) }

  let(:mp3_file) { nil }
  let(:track) { create(:track) }

  context 'with invalid file path' do
    let(:mp3_file) { 'nonexistent/path' }

    it 'raises exception' do
      expect { service.call }.to raise_error(Errno::ENOENT)
    end
  end

  context 'with valid file path' do
    context 'with non-mp3 file' do
      let(:mp3_file) { Rails.root.join('spec/fixtures/textfile.txt') }

      it 'raises exception' do
        expect { service.call }.to raise_error(Mp3InfoEOFError)
      end
    end

    context 'with mp3 file' do
      let(:mp3_file) { track.audio_file.path }

      it 'returns duration of mp3 in seconds' do
        expect(service.call).to eq(2_011)
      end
    end
  end
end
