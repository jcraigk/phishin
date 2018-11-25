# frozen_string_literal: true
module AmbiguousSlugs::Date
  def slug_as_date
    slug = params[:slug]
    return false unless slug =~ /\A\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}\z/

    # 2012.12.31 => 2012-12-31
    r = Regexp.last_match
    slug = "#{r[1]}-#{r[2]}-#{r[3]}" if slug =~ /\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/

    @show = Show.includes(tracks: %i[songs tags]).find_by!(date: slug)

    @sets = {}
    tracks = @show.tracks.sort_by(&:position)
    tracks.group_by(&:set_name).each do |set, track_list|
      @sets[set] = {
        duration: track_list.map(&:duration).inject(0, &:+),
        tracks: track_list,
        likes: get_user_likes_for_tracks(track_list)
      }
    end
    @show_like = get_user_likes_for_shows([@show])
    @show_like = nil

    set_next_show
    set_previous_show

    @view = 'shows/show'

    true
  end

  private

  def set_next_show
    @next_show =
      Show.avail
          .where('date > ?', @show.date)
          .order(date: :asc)
          .first ||
      Show.avail
          .order(date: :asc)
          .first
  end

  def set_previous_show
    @previous_show =
      Show.avail
          .where('date < ?', @show.date)
          .order(date: :desc)
          .first ||
      Show.avail
          .order(date: :desc)
          .first
  end
end
