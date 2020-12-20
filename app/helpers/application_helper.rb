# frozen_string_literal: true
module ApplicationHelper
  def clear_both
    tag.div(style: 'clear: both;')
  end

  def duration_readable(milliseconds, style = 'colons')
    DurationFormatter.new(milliseconds, style).call
  end

  def total_hours_of_music
    (Show.all.sum(&:duration) / 3_600_000.to_f).round
  end

  def link_to_song(song, term = nil)
    title = song_title_with_alias(song)
    title = highlight(title, term) if term.present?
    link_to(title, "/#{song.slug}")
  end

  def song_title_with_alias(song)
    title = song.title
    title += " (aka #{song.alias})" if song.alias.present?
    title
  end

  def performances_link(song)
    pluralize(song.tracks_count, 'track')
  end

  def likable(likable, like, size)
    likable_name = likable.class.name.downcase
    a = link_to(
      '', 'null',
      data: { type: likable_name, id: likable.id },
      class: like.present? ? %i[like_toggle liked] : %i[like_toggle],
      title: "Click to Like or Unlike this #{likable_name}"
    )
    span = tag.span(likable.likes_count)
    str = tag.div(a + span, class: "likes_#{size}")
    str.html_safe
  end

  def link_to_show(show, show_abbrev: true)
    link_name = show_link_title(show, show_abbrev: show_abbrev)
    link_to(link_name, "/#{show.date}")
  end

  def show_link_title(show, show_abbrev: true)
    show_abbrev ? show.date.strftime('%b %-d') : show.date_with_dots
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

  def taper_notes_for(show)
    return CGI.escapeHTML(show.taper_notes) if show.taper_notes.present?
    'No taper notes present for this show'.html_safe
  end

  def pluralize_with_delimiter(count, word)
    "#{number_with_delimiter(count)} #{word.pluralize(count)}".html_safe
  end

  def default_map_path
    '/map?map_term=Burlington%20VT&distance=10'
  end

  def slug_for_set(set)
    set.downcase.tr(' ', '-')
  end
end
