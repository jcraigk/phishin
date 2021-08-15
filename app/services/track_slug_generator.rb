# frozen_string_literal: true
class TrackSlugGenerator
  attr_reader :track

  def initialize(track)
    @track = track
  end

  def call
    unique_slug_scoped_to_show
  end

  private

  def unique_slug_scoped_to_show
    "#{base_slug}#{suffix}"
  end

  def suffix
    return if num_dupe_titles_before.zero?
    "-#{num_dupe_titles_before + 1}"
  end

  def num_dupe_titles_before
    num = 0
    existing_tracks.each do |t|
      break if t == track
      num += 1 if t.title == track.title
    end
    num
  end

  def existing_tracks
    @existing_tracks = track.show.tracks.order(position: :asc)
  end

  def base_slug
    @base_slug ||= abbreviate_long_slug(slugged_title)
  end

  def slugged_title
    @slugged_title ||=
      track.title
           .downcase
           .delete("'")
           .gsub(/[^a-z0-9]/, ' ')
           .strip
           .gsub(/\s+/, '-')
  end

  def abbreviate_long_slug(slug)
    slug.gsub!(/hold-your-head-up/, 'hyhu')
    slug.gsub!(/the-man-who-stepped-into-yesterday/, 'tmwsiy')
    slug.gsub!(/she-caught-the-katy-and-left-me-a-mule-to-ride/, 'she-caught-the-katy')
    slug.gsub!(/mcgrupp-and-the-watchful-hosemasters/, 'mcgrupp')
    slug.gsub!(/big-black-furry-creature-from-mars/, 'bbfcfm')
    slug
  end
end
