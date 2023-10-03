require 'rails_helper'

RSpec.describe DateParser do
  subject(:service) { described_class.new(date) }

  let(:formatted_date) { '1995-10-31' }

  shared_examples 'successful parse' do
    it 'returns formatted date' do
      expect(service.call).to eq(formatted_date)
    end
  end

  context 'with invalid date' do
    let(:date) { 'blah' }

    it 'returns false' do
      expect(service.call).to be(false)
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
