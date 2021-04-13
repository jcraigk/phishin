# frozen_string_literal: true
require 'rails_helper'

RSpec.describe AudioFileUploader do
  let(:track) do
    create(:track, audio_file: File.open("#{Rails.root}/spec/fixtures/test.mp3", 'rb'))
  end
  let(:audio_file) { track.audio_file }

  it 'extracts metadata' do
    expect(audio_file.mime_type).to eq('audio/mpeg')
    expect(audio_file.extension).to eq('mp3')
    expect(audio_file.size).to be_instance_of(Integer)
  end
end
