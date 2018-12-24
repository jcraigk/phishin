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
    return unless existing_titles.include?(new_title)
    "-#{existing_titles.count(new_title) + 1}"
  end

  def new_title
    @new_title ||= track.title
  end

  def existing_titles
    @existing_titles = Track.where(show_id: track.show_id).map(&:title)
  end

  def base_slug
    @base_slug ||= abbreviate_long_slug(slugged_title)
  end

  def slugged_title
    @sluggified_title ||=
      track.title
           .downcase
           .gsub(/[^a-z0-9]/, ' ')
           .strip
           .gsub(/\s+/, '-')
  end

  def abbreviate_long_slug(slug)
    slug.gsub!(/hold\-your\-head\-up/, 'hyhu')
    slug.gsub!(/the\-man\-who\-stepped\-into\-yesterday/, 'tmwsiy')
    slug.gsub!(/she\-caught\-the\-katy\-and\-left\-me\-a\-mule\-to\-ride/, 'she-caught-the-katy')
    slug.gsub!(/mcgrupp\-and\-the\-watchful\-hosemasters/, 'mcgrupp')
    slug.gsub!(/big\-black\-furry\-creature\-from\-mars/, 'bbfcfm')
    slug
  end
end
