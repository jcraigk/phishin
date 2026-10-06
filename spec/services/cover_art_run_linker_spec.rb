require "rails_helper"

RSpec.describe CoverArtRunLinker do
  let(:venue) { create(:venue) }
  let(:image_path) { Rails.root.join("spec/fixtures/files/cover-art-large.jpg") }
  let!(:parent) do
    create(:show, date: "2026-10-02", venue:, cover_art_prompt: "A gull", cover_art_model: "google/gemini-3-pro-image")
  end
  let(:show) { create(:show, date: "2026-10-03", venue:, published: false) }

  before do
    allow(AlbumCoverService).to receive(:call)
    allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
  end

  def attach_parent_art
    parent.cover_art.attach(io: File.open(image_path), filename: "art.jpg", content_type: "image/jpeg")
  end

  it "links a show to the first show of its run" do
    third = create(:show, date: "2026-10-04", venue:)
    show
    described_class.call(third)
    expect(third.reload.cover_art_parent_show_id).to eq(parent.id)
  end

  it "copies the run's prompt" do
    described_class.call(show)
    expect(show.reload.cover_art_prompt).to eq("A gull")
  end

  it "gives the show the parent's cover art blob" do
    attach_parent_art
    described_class.call(show)
    expect(show.reload.cover_art.blob).to eq(parent.cover_art.blob)
  end

  it "gives the show the parent's cover art model" do
    attach_parent_art
    described_class.call(show)
    expect(show.reload.cover_art_model).to eq("google/gemini-3-pro-image")
  end

  it "composites an album cover from the inherited art" do
    attach_parent_art
    described_class.call(show)
    expect(AlbumCoverService).to have_received(:call).with(show)
  end

  it "skips art when the parent has none" do
    described_class.call(show)
    expect(show.reload.cover_art).not_to be_attached
  end

  it "does not rebuild the album cover when the art is already the parent's" do
    attach_parent_art
    show.cover_art.attach(parent.cover_art.blob)
    described_class.call(show)
    expect(AlbumCoverService).not_to have_received(:call)
  end

  it "does not link across venues" do
    show.update!(venue: create(:venue))
    described_class.call(show)
    expect(show.reload.cover_art_parent_show_id).to be_nil
  end

  it "does not link shows more than four days apart" do
    late = create(:show, date: "2026-10-07", venue:)
    described_class.call(late)
    expect(late.reload.cover_art_parent_show_id).to be_nil
  end

  it "clears a stale link when the show starts its own run" do
    show.update!(cover_art_parent_show_id: parent.id, venue: create(:venue))
    described_class.call(show)
    expect(show.reload.cover_art_parent_show_id).to be_nil
  end
end
