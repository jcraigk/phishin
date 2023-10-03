require 'rails_helper'

RSpec.describe DurationFormatter do
  subject(:service) { described_class.new(duration, style) }

  let(:duration) { 0 }

  shared_examples 'expected string' do
    it 'returns expected string' do
      expect(service.call).to eq(expected_string)
    end
  end

  shared_examples 'colon style' do
    context 'with duration over a day' do
      let(:duration) { 92_098_000 }
      let(:expected_string) { '1:01:34:58' }

      include_examples 'expected string'
    end

    context 'with duration over an hour' do
      let(:duration) { 22_140_000 }
      let(:expected_string) { '6:09:00' }

      include_examples 'expected string'
    end

    context 'with duration over a minute' do
      let(:duration) { 2_254_000 }
      let(:expected_string) { '37:34' }

      include_examples 'expected string'
    end

    context 'with duration over a second' do
      let(:duration) { 34_000 }
      let(:expected_string) { '0:34' }

      include_examples 'expected string'
    end

    context 'with duration under a second' do
      let(:duration) { 700 }
      let(:expected_string) { '0:00' }

      include_examples 'expected string'
    end
  end

  context 'with nil style' do
    let(:style) { nil }

    include_examples 'colon style'
  end

  context 'with colon style' do
    let(:style) { 'colons' }

    include_examples 'colon style'
  end

  context 'with letter style' do
    let(:style) { 'letters' }

    context 'with duration over a day' do
      let(:duration) { 92_098_000 }
      let(:expected_string) { '1d 1h 34m 58s' }

      include_examples 'expected string'
    end

    context 'with duration over an hour' do
      let(:duration) { 22_140_000 }
      let(:expected_string) { '6h 9m' }

      include_examples 'expected string'
    end

    context 'with duration exactly 2 hours' do
      let(:duration) { 7_200_000 }
      let(:expected_string) { '2h' }

      include_examples 'expected string'
    end

    context 'with duration over a minute' do
      let(:duration) { 2_254_000 }
      let(:expected_string) { '37m 34s' }

      include_examples 'expected string'
    end

    context 'with duration exactly 2 minutes' do
      let(:duration) { 120_000 }
      let(:expected_string) { '2m' }

      include_examples 'expected string'
    end

    context 'with duration over a second' do
      let(:duration) { 34_000 }
      let(:expected_string) { '0m 34s' }

      include_examples 'expected string'
    end

    context 'with duration under a second' do
      let(:duration) { 700 }
      let(:expected_string) { '0s' }

      include_examples 'expected string'
    end
  end
end
