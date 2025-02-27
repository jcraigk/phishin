require 'rails_helper'

RSpec.describe Show do
  subject(:show) { create(:show) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:tour) }
  it { is_expected.to belong_to(:venue) }

  it { is_expected.to have_many(:tracks).dependent(:destroy) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to have_many(:show_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags) }

  it { is_expected.to validate_presence_of(:date) }
  it { is_expected.to validate_uniqueness_of(:date) }

  it { is_expected.to delegate_method(:name).to(:tour).with_prefix }

  describe '#cache_venue_name' do
    let(:venue) { create(:venue) }
    let(:date) { '2018-01-01' }
    let(:show) { build(:show, venue:, date:) }

    context 'when there are no venue renames' do
      it 'caches the venue name before validation' do
        show.validate
        expect(show.venue_name).to eq(venue.name)
      end
    end

    context 'when there is a venue rename in the past' do
      let(:rename) { 'Venue New Name' }

      before do
        create(
          :venue_rename,
          venue:,
          renamed_on: Date.parse('2018-01-01') - 1.day,
          name: rename
        )
        show.validate
      end

      it 'caches the latest venue rename before validation' do
        expect(show.venue_name).to eq(rename)
      end
    end
  end

  describe 'scopes' do
    describe '#between_years' do
      let!(:show1) { create(:show, date: '2014-10-31') }
      let!(:show2) { create(:show, date: '2015-01-01') }

      before do
        create(:show, date: '2016-01-01')
        create(:show, date: '2017-01-01')
      end

      it 'returns expected objects' do
        expect(described_class.between_years(2014, 2015)).to eq([ show1, show2 ])
      end
    end

    describe '#during_year' do
      let!(:show1) { create(:show, date: '2014-10-31') }

      before do
        create(:show, date: '2015-01-01')
      end

      it 'returns expected objects' do
        expect(described_class.during_year(2014)).to eq([ show1 ])
      end
    end

    describe '#on_day_of_year' do
      let!(:show1) { create(:show, date: '2018-10-31') }

      before do
        create(:show, date: '2018-01-01')
      end

      it 'returns expected object' do
        expect(described_class.on_day_of_year(10, 31)).to eq([ show1 ])
      end
    end

    describe '#published' do
      let!(:show2) { create(:show, published: true) }
      let!(:show3) { create(:show, published: true) }

      before { create(:show, published: false) }

      it 'returns published shows' do
        expect(described_class.published.order(date: :asc)).to contain_exactly(show2, show3)
      end
    end

    describe "#random" do
      let!(:shows) { create_list(:show, 5) }

      it "returns a single random show" do
        expect(described_class.random.count).to eq(1)
        expect(shows).to include(described_class.random.first)
      end

      it "returns multiple random shows when an amount is specified" do
        expect(described_class.random(3).count).to eq(3)
      end

      it "returns different results across multiple calls" do
        first_run = described_class.random(3)
        second_run = described_class.random(3)

        expect(first_run).not_to eq(second_run) unless first_run == second_run
      end

      it "returns different results across multiple calls (stubbed randomness)" do
        allow(described_class).to receive(:order).and_return(described_class.limit(2))
        expect(described_class.random(2).count).to eq(2)
      end
    end

    describe '#tagged_with' do
      let!(:shows) { create_list(:show, 2) }
      let(:tag) { create(:tag) }

      before { shows.first.tags << tag }

      it 'returns expected objects' do
        expect(described_class.tagged_with(tag.slug)).to eq([ shows.first ])
      end
    end
  end

  it 'provides #date_with_dots' do
    expect(show.date_with_dots).to eq(show.date.strftime('%Y.%m.%d'))
  end

  describe '#save_duration' do
    subject(:show) { create(:show, :with_tracks) }

    let(:track_sum) { show.tracks.sum(&:duration) }

    it 'updates the duration with the sum of all tracks' do
      show.save_duration
      expect(show.duration).to eq(track_sum)
    end
  end

  describe 'serialization' do
    let!(:show_tags) { create_list(:show_tag, 3, show:) }
    let(:expected_as_json) do
      {
        id: show.id,
        date: show.date.iso8601,
        duration: show.duration,
        incomplete: show.incomplete,
        sbd: false, # Shim for RoboPhish/Android
        remastered: false, # Shim for RoboPhish/Android
        tour_id: show.tour_id,
        venue_id: show.venue_id,
        likes_count: show.likes_count,
        taper_notes: show.taper_notes,
        updated_at: show.updated_at.iso8601,
        venue_name: show.venue&.name,
        location: show.venue&.location
      }
    end
    let(:tags) do
      show_tags.map do |show_tag|
        {
          id: show_tag.tag.id,
          name: show_tag.tag.name,
          priority: show_tag.tag.priority,
          group: show_tag.tag.group,
          color: show_tag.tag.color,
          notes: show_tag.notes
        }
      end
    end
    let(:expected_as_json_api) do
      {
        id: show.id,
        date: show.date.iso8601,
        duration: show.duration,
        incomplete: show.incomplete,
        sbd: false, # Shim for RoboPhish/Android
        remastered: false, # Shim for RoboPhish/Android
        tags: tags.sort_by { |t| t[:priority] },
        tour_id: show.tour_id,
        venue: show.venue.as_json,
        venue_name: show.venue_name,
        taper_notes: show.taper_notes,
        likes_count: show.likes_count,
        tracks: show.tracks.sort_by(&:position).map(&:as_json_api),
        updated_at: show.updated_at.iso8601
      }
    end

    it 'provides #as_json' do
      expect(show.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(show.as_json_api).to eq(expected_as_json_api)
    end
  end
end
