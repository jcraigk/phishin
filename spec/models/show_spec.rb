# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Show do
  subject { build(:show) }

  it { is_expected.to belong_to(:tour) }
  it { is_expected.to belong_to(:venue) }

  it { is_expected.to have_many(:tracks).dependent(:destroy) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to have_many(:show_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags) }

  it { is_expected.to validate_presence_of(:date) }

  it { should delegate_method(:name).to(:tour).with_prefix }

  context 'scopes' do
    context '#avail' do
      let!(:show1) { create(:show) }
      let!(:show2) { create(:show, missing: true) }

      it 'returns expected objects' do
        expect(described_class.avail).to eq([show1])
      end
    end

    context '#between_years' do
      let!(:show1) { create(:show, date: '2014-10-31') }
      let!(:show2) { create(:show, date: '2015-01-01') }
      let!(:show3) { create(:show, date: '2016-01-01') }
      let!(:show4) { create(:show, date: '2017-01-01') }

      it 'returns expected objects' do
        expect(described_class.between_years(2014, 2015)).to eq([show1, show2])
      end
    end

    context '#during_year' do
      let!(:show1) { create(:show, date: '2014-10-31') }
      let!(:show2) { create(:show, date: '2015-01-01') }

      it 'returns expected objects' do
        expect(described_class.during_year(2014)).to eq([show1])
      end
    end

    context '#on_day_of_year' do
      let!(:show1) { create(:show, date: '2018-10-31') }
      let!(:show2) { create(:show, date: '2018-01-01') }

      it 'returns expected object' do
        expect(described_class.on_day_of_year(10, 31)).to eq([show1])
      end
    end

    context '#random' do
      let(:mock_subject) { spy(described_class) }

      xit 'makes expected calls' do
        expect(described_class).to receive(:order).with('RANDOM()').and_return(mock_subject)
        expect(mock_subject).to receive(:limit).with(2)
        described_class.random
      end
    end

    context '#tagged_with' do
      let!(:shows) { create_list(:show, 2) }
      let(:tag) { create(:tag) }

      before { shows.first.tags << tag }

      it 'returns expected objects' do
        expect(described_class.tagged_with(tag.name)).to eq([shows.first])
      end
    end
  end

  context '#save_duration' do
    let(:track_sum) { subject.tracks.map(&:duration).inject(0, &:+) }
    subject { create(:show, :with_tracks) }

    it 'updates the duration with the sum of all tracks' do
      expect(subject.duration).not_to eq(track_sum)
      subject.save_duration
      expect(subject.duration).to eq(track_sum)
    end
  end

  context 'serialization' do
    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        date: subject.date.to_s,
        duration: subject.duration,
        incomplete: subject.incomplete,
        missing: subject.missing,
        sbd: subject.sbd,
        remastered: subject.remastered,
        tour_id: subject.tour_id,
        venue_id: subject.venue_id,
        likes_count: subject.likes_count,
        taper_notes: subject.taper_notes,
        updated_at: subject.updated_at.to_s,
        venue_name: subject.venue&.name,
        location: subject.venue&.location
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        date: subject.date.to_s,
        duration: subject.duration,
        incomplete: subject.incomplete,
        missing: subject.missing,
        sbd: subject.sbd,
        remastered: subject.remastered,
        tags: subject.tags.sort_by(&:priority).map(&:name).as_json,
        tour_id: subject.tour_id,
        venue: subject.venue.as_json,
        taper_notes: subject.taper_notes,
        likes_count: subject.likes_count,
        tracks: subject.tracks.sort_by(&:position).map(&:as_json_api),
        updated_at: subject.updated_at.to_s
      )
    end
  end
end
