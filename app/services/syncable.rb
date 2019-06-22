module Syncable
  private

  def seconds_or_nil(str)
    return if str.nil? || str.empty?
    min, sec = str.split(':')
    min.to_i * 60 + sec.to_i
  end

  def find_track_by_url(url)
    Track.find_by(
      slug: track_slug(url),
      show: show_from_url(url)
    )
  end

  def show_from_url(url)
    Show.find_by(date: show_slug(url))
  end

  def path_segments(url)
    url.split('/')
  end

  def track_slug(url)
    path_segments(url).last
  end

  def show_slug(url)
    path_segments(url)[-2]
  end
end
