require "rails_helper"

RSpec.describe TrackSlugAbbreviator do
  let(:show) { create(:show, date: "1993-03-24") }

  def track_with_slug(title, slug, position: 1)
    track = create(:track, show:, title:, position:)
    track.update_column(:slug, slug)
    track
  end

  it "reports long-form slugs without changing them by default" do
    track = track_with_slug("You Enjoy Myself", "you-enjoy-myself")

    updates = described_class.call

    expect(updates.map { |u| u[:to] }).to eq([ "yem" ])
    expect(track.reload.slug).to eq("you-enjoy-myself")
  end

  it "abbreviates when dry_run is false" do
    track = track_with_slug("You Enjoy Myself", "you-enjoy-myself")

    described_class.call(dry_run: false)

    expect(track.reload.slug).to eq("yem")
  end

  it "abbreviates every configured long form" do
    tracks = {
      "you-enjoy-myself" => "yem",
      "hold-your-head-up" => "hyhu",
      "big-black-furry-creature-from-mars" => "bbfcfm",
      "mcgrupp-and-the-watchful-hosemasters" => "mcgrupp",
      "the-man-who-stepped-into-yesterday" => "tmwsiy",
      "she-caught-the-katy-and-left-me-a-mule-to-ride" => "she-caught-the-katy"
    }.each_with_index.map do |(slug, expected), idx|
      [ track_with_slug("Song #{idx}", slug, position: idx + 1), expected ]
    end

    described_class.call(dry_run: false)

    tracks.each { |track, expected| expect(track.reload.slug).to eq(expected) }
  end

  it "abbreviates long forms embedded in a segued slug" do
    track = track_with_slug("HYHU > Terrapin", "hold-your-head-up-terrapin")

    described_class.call(dry_run: false)

    expect(track.reload.slug).to eq("hyhu-terrapin")
  end

  it "preserves a numeric dedupe suffix" do
    track = track_with_slug("You Enjoy Myself", "you-enjoy-myself-2")

    described_class.call(dry_run: false)

    expect(track.reload.slug).to eq("yem-2")
  end

  it "leaves already-abbreviated slugs alone" do
    track = track_with_slug("You Enjoy Myself", "yem")

    expect(described_class.call).to be_empty
    expect(track.reload.slug).to eq("yem")
  end

  it "skips a rewrite that would collide within the same show" do
    long = track_with_slug("You Enjoy Myself", "you-enjoy-myself", position: 1)
    track_with_slug("You Enjoy Myself", "yem", position: 2)

    expect(described_class.call).to be_empty
    expect(long.reload.slug).to eq("you-enjoy-myself")
  end

  it "does not touch unrelated slugs" do
    track = track_with_slug("Quinn the Eskimo (The Mighty Quinn)", "quinn-the-eskimo")

    described_class.call(dry_run: false)

    expect(track.reload.slug).to eq("quinn-the-eskimo")
  end

  it "allows the same slug in different shows" do
    other = create(:show, date: "1994-05-07")
    a = track_with_slug("You Enjoy Myself", "you-enjoy-myself")
    b = create(:track, show: other, title: "You Enjoy Myself", position: 1)
    b.update_column(:slug, "you-enjoy-myself")

    described_class.call(dry_run: false)

    expect(a.reload.slug).to eq("yem")
    expect(b.reload.slug).to eq("yem")
  end
end
