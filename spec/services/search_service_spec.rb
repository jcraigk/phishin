require 'rails_helper'

RSpec.describe SearchService do
  subject(:service) { described_class.new(term, scope) }

  let(:term) { nil }
  let(:scope) { nil }

  shared_examples 'expected results' do
    it 'returns expected results' do
      expect(service.call.as_json).to eq(expected_results.as_json)
    end
  end

  context 'with invalid term' do
    let(:term) { 'a' }

    it 'returns empty hash' do
      expect(service.call).to be_nil
    end
  end

  context 'with date-based terms' do
    let(:date) { Date.parse("2024-10-31") }
    let(:expected_results) do
      {
        exact_show: show1,
        other_shows: [ show2, show3 ],
        songs: [],
        venues: [],
        tags: [ tag ],
        show_tags: [ show_tag ],
        track_tags: [ track_tag ],
        tracks: [],
        playlists: []
      }
    end
    let!(:show1) { create(:show, date:) }
    let!(:show2) { create(:show, date: date - 1.year) }
    let!(:show3) { create(:show, date: date - 2.years) }
    let!(:tag) { create(:tag, name: "Date #{term}") }
    let!(:show_tag) { create(:show_tag, notes: "... blah #{term} ...") }
    let!(:track_tag) { create(:track_tag, notes: "... blah blah #{term} blah..") }

    before do
      create(:show, date: date - 1.day)
    end

    context 'with exact is8601 date' do
      let(:term) { "2024-10-31" }

      it_behaves_like 'expected results'
    end

    context 'with English month and day' do
      let(:term) { 'october 31' }
      let(:expected_results) do
        super().merge \
          exact_show: nil,
          other_shows: [ show1, show2, show3 ]
      end

      it_behaves_like 'expected results'
    end

    context 'with shortened English month and day and shortened year' do
      let(:term) { 'oct 31, 2024' }

      it_behaves_like 'expected results'
    end
  end

  context 'with text-based term' do
    let(:term) { 'hood' }
    let(:expected_results) do
      {
        exact_show: nil,
        other_shows: [],
        songs: [ song1, song2 ],
        venues: [ venue1, venue3 ],
        tags: [ tag2, tag1 ],
        show_tags: [ show_tag ],
        track_tags: [ track_tag ],
        tracks: [ track ],
        playlists: []
      }
    end
    let!(:show_tag) { create(:show_tag, notes: "... blah #{term} ...") }
    let!(:song1) { create(:song, title: 'Harry Hood') }
    let!(:song2) { create(:song, title: 'Hoodenstein') }
    let!(:tag1) { create(:tag, name: 'Hood Tag') }
    let!(:tag2) { create(:tag, name: 'All Hood') }
    let!(:track_tag) { create(:track_tag, notes: "... blah blah #{term} blah..") }
    let!(:venue1) { create(:venue, name: 'Hood\'s Place') }
    let!(:venue3) { create(:venue, name: 'Hoody') }
    let!(:track) { create(:track, title: "Foo #{term.upcase}") }

    before do
      create(:venue, name: 'Nectar\'s')
      create(:song, title: 'Bathtub Gin')
      create(:tag, name: 'Something Else')
    end

    it_behaves_like 'expected results'
  end

  context 'with scope set to "tags"' do
    let(:term) { 'tag_search' }
    let(:scope) { 'tags' }
    let(:expected_results) do
      {
        tags: [ tag ],
        show_tags: [ show_tag ],
        track_tags: [ track_tag ]
      }
    end
    let!(:tag) { create(:tag, name: "Tag #{term}") }
    let!(:show_tag) { create(:show_tag, notes: "Tagged show #{term}") }
    let!(:track_tag) { create(:track_tag, notes: "Tagged track #{term}") }

    it_behaves_like 'expected results'
  end

  context 'with scope set to "shows"' do
    let(:term) { show.date.to_s }
    let(:scope) { 'shows' }
    let(:expected_results) do
      {
        exact_show: show,
        other_shows: [ other_show ]
      }
    end
    let!(:show) { create(:show, date: Date.today) }
    let!(:other_show) { create(:show, date: Date.today - 1.year) }

    it_behaves_like 'expected results'
  end

  context 'with scope set to "playlists"' do
    let(:term) { 'hood' }
    let(:scope) { 'playlists' }
    let(:expected_results) { { playlists: [ playlist1, playlist2 ] } }
    let!(:playlist1) { create(:playlist, name: "A Playlist #{term}") }
    let!(:playlist2) { create(:playlist, name: "B Greatest Hits", description: 'Some good hoods') }

    before { create(:playlist, name: "Other Playlist", description: "Nutn") }

    it_behaves_like 'expected results'
  end
end
