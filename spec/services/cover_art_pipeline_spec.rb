require "rails_helper"
require "mini_magick"

# Exercises the full local image pipeline a show's cover art goes through:
#   attach_cover_art_by_path (HasCoverArt) -> medium/small variants
#   AlbumCoverService        -> album_cover (composited text) -> :id3 variant
#
# This is the deterministic, offline processing (MiniMagick + image_processing /
# Active Storage variants) -- it does NOT call the external AI image generator.
#
# Every produced image is written to tmp/spec_artifacts/cover_art/ so the complete
# set can be inspected after each run.
RSpec.describe "Cover art image pipeline" do # rubocop:disable RSpec/DescribeClass
  let(:show) do
    create(:show, date: "1997-11-22", venue: create(:venue, name: "Hampton Coliseum"))
  end
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/cover-art-large.jpg").to_s }

  it "processes cover art, builds the album cover, and produces every variant" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    CoverArtArtifacts.reset!

    # 1. Source image -> processed cover_art (1024x1024 JPEG)
    show.attach_cover_art_by_path(fixture_path)
    expect(show.cover_art).to be_attached

    large = MiniMagick::Image.open(CoverArtArtifacts.dump("cover_art_large", show.cover_art))
    expect(large.type).to eq("JPEG")
    expect(large.dimensions).to eq([ 1024, 1024 ])

    # 2. Active Storage variants (resize_to_limit via image_processing) -- the path
    #    that breaks when the imaging backend is missing or image_processing changes.
    medium = MiniMagick::Image.open(CoverArtArtifacts.dump("cover_art_medium", show.cover_art.variant(:medium).processed))
    expect(medium.type).to eq("JPEG")
    expect(medium.width).to be <= 256
    expect(medium.height).to be <= 256

    small = MiniMagick::Image.open(CoverArtArtifacts.dump("cover_art_small", show.cover_art.variant(:small).processed))
    expect(small.type).to eq("JPEG")
    expect(small.width).to be <= 40
    expect(small.height).to be <= 40

    # 3. AlbumCoverService composites date/venue text onto the cover art
    AlbumCoverService.call(show)
    expect(show.album_cover).to be_attached

    album = MiniMagick::Image.open(CoverArtArtifacts.dump("album_cover", show.album_cover))
    expect(album.type).to eq("JPEG")
    expect(album.dimensions).to eq([ 1024, 1024 ])
    # Compositing must have changed the pixels, not just copied the source.
    expect(show.album_cover.download).not_to eq(show.cover_art.download)

    # 4. The :id3 variant embedded into downloadable MP3s (resize_to_limit 600)
    id3 = MiniMagick::Image.open(CoverArtArtifacts.dump("album_cover_id3", show.album_cover.variant(:id3).processed))
    expect(id3.type).to eq("JPEG")
    expect(id3.width).to be <= 600
    expect(id3.height).to be <= 600
  end
end
