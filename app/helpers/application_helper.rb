# frozen_string_literal: true
module ApplicationHelper
  def clear_both
    content_tag(:div, '', style: 'clear: both;')
  end

  def total_hours_of_music
    (Show.avail.map(&:duration).inject(0, &:+) / 3_600_000).round
  end

  def duration_readable(milliseconds, style = 'colon')
    x = milliseconds / 1000
    seconds = x % 60
    x /= 60
    minutes = x % 60
    x /= 60
    hours = x % 24
    x /= 24
    days = x
    if style == 'letters'
      if days.positive?
        format(
          '%<days>dd %<hours>dh %<minutes>dm',
          days: days,
          hours: hours,
          minutes: minutes
        )
      elsif hours.positive?
        format(
          '%<hours>dh %<minutes>dm',
          hours: hours,
          minutes: minutes
        )
      else
        format(
          '%<minutes>dm %<seconds>ds',
          minutes: minutes,
          seconds: seconds
        )
      end
    elsif days.positive?
      format(
        '%<days>d:%<hours>02d:%<minutes>02d:%<seconds>02d',
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds
      )
    elsif hours.positive?
      format(
        '%<hours>d:%<minutes>02d:%<seconds>02d',
        hours: hours,
        minutes: minutes,
        seconds: seconds
      )
    else
      format(
        '%<minutes>d:%<seconds>02d',
        minutes: minutes,
        seconds: seconds
      )
    end
  end

  def link_to_song(song, term = nil)
    slug = song.aliased_song ? "/#{song.aliased_song.slug}" : "/#{song.slug}"
    title = (term ? highlight(song.title, term) : song.title)
    link_to title, slug
  end

  def performances_or_alias_link(song)
    return pluralize(song.tracks_count, 'track') unless song.aliased_song
    link_to("alias for #{song.aliased_song.title}", song.aliased_song.slug, class: :alias_for)
  end

  def likable(likable, like, size)
    likable_name = likable.class.name.downcase
    css = like.present? ? %i[like_toggle liked] : %i[like_toggle]
    a = link_to(
      '',
      'null',
      data: {
        type: likable_name,
        id: likable.id
      },
      class: css,
      title: "Click to Like or Unlike this #{likable_name}"
    )
    span = content_tag(:span, likable.likes_count)
    str = content_tag(:div, a + span, class: "likes_#{size}")
    str.html_safe
  end

  def link_to_show(show, show_abbrev = true)
    link_name = show_link_title(show, show_abbrev)
    link_to(link_name, "/#{show.date}")
  end

  def show_link_title(show, show_abbrev = true)
    show_abbrev ? show.date.strftime('%b %-d') : show.date.strftime('%Y.%m.%d')
  end

  def linked_show_date(show)
    day_link = link_to(
      show.date.strftime('%b %-d'),
      "/#{show.date.strftime('%B').downcase}-#{show.date.strftime('%-d')}"
    )
    year_link = link_to(
      show.date.strftime('%Y'),
      "/#{show.date.strftime('%Y')}"
    )
    "#{day_link}, #{year_link}".html_safe
  end

  def xhr_exempt_controller
    controller_name.in?(
      %w[
        sessions registrations confirmations
        passwords unlocks omniauth_callbacks
        downloads errors
      ]
    )
  end

  def taper_notes_or_missing(show)
    show.taper_notes.present? ? CGI.escapeHTML(show.taper_notes) : 'No taper notes present for this show'.html_safe
  end

  def pluralize_with_delimiter(count, word)
    "#{number_with_delimiter(count)} #{word.pluralize(count)}".html_safe
  end

  def default_map_path
    '/map?map_term=Burlington%20VT&distance=10'
  end
end
