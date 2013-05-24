module ApplicationHelper
  
  def sort_songs_links(item_hash)
    str = ''
    item_hash.each do |key, val|
      link = params[:sort] == val ? "<strong>#{key}</strong>" : key
      str += content_tag :li, link_to(link.html_safe, "?char=#{params[:char]}&sort=#{CGI::escape(val)}")
    end
    str.html_safe
  end
  
  def first_char_links(base_url)
    str = ''
    FIRST_CHAR_LIST.each do |char|
      css = "char_link #{params[:char] == char ? " active" : ""}"
      str += link_to char, "#{base_url}?char=#{CGI::escape(char)}", class: css
    end
    str.html_safe
  end
  
  def will_paginate_simple(collection)
    will_paginate collection, inner_window: 2, outer_window: 0, previous_label: '<i class="icon-chevron-left"></i>', next_label: '<i class="icon-chevron-right"></i>', params: [:per_page, :t]
  end

  def duration_readable(ms, style='colon')
    x = ms / 1000
    seconds = x % 60
    x /= 60
    minutes = x % 60
    x /= 60
    hours = x % 24
    x /= 24
    days = x
    if style == 'letters'
      if days > 0
        "%dd %02dh %02dm" % [days, hours, minutes]
      elsif hours > 0
        "%dh %02dm" % [hours, minutes]
      else
        "%dm %02ds" % [minutes, seconds]
      end
    else
      if days > 0
        "%d:%02d:%02d" % [days, hours, minutes]
      elsif hours > 0
        "%d:%02d" % [hours, minutes]
      else
        "%d:%02d" % [minutes, seconds]
      end
    end
  end
  
  def nav_button(name, path, other_path='')
    link_to (content_tag :span, name, class: 'badge'), path, data: { 'alt-href' => other_path }
  end
  
  def link_to_song(song, term=nil)
    slug = song.aliased_song ? "/#{song.aliased_song.slug}" : "/#{song.slug}"
    title = (term ? highlight(song.title, term) : song.title)
    link_to title, slug
  end
  
  def performances_or_alias_link(song, display_title=false)
    tracks_count = (display_title ? song.tracks_count : song.tracks_count)
    song.aliased_song ? (link_to "alias for #{song.aliased_song.title}", "#{song.aliased_song.slug}", class: :alias_for) : pluralize(tracks_count, 'track')
  end
  
  def likable(likable, like, size)
    likable_name = likable.class.name.downcase
    css = (like.present? ? [:like_toggle, :liked] : [:like_toggle])
    a = link_to '', 'null', data: { type: likable_name, id: likable.id}, class: css, title: "Click to Like or Unlike this #{likable_name}"
    span = content_tag :span, likable.likes_count
    str = content_tag :div, a + span, class: "likes_#{size}"
    str.html_safe
  end
  
  def link_to_show(show, show_abbrev=true)
    link_name = show_link_title(show, show_abbrev)
    link_to(link_name, "/#{show.date}")
  end
  
  def show_link_title(show, show_abbrev=true)
    show_abbrev ? show.date.strftime("%b %-d") : show.date.strftime("%-m/%-d/%y")
  end
  
  private
  
  def linked_show_date(show)
    day_link = link_to show.date.strftime("%b %-d"), "/#{show.date.strftime("%B").downcase}-#{show.date.strftime("%-d")}"
    year_link = link_to show.date.strftime("%Y"), "/#{show.date.strftime("%Y")}"
    "#{day_link}, #{year_link}".html_safe
  end
  
  def xhr_exempt_controller
    devise_controllers = %w(sessions registrations confirmations passwords unlocks omniauth_callbacks)
    special_controllers = %w(downloads errors)
    exempt_controllers = devise_controllers + special_controllers
    exempt_controllers.include? controller_name
  end
  
  def track_title_with_tags(track)
    max_len = 45
    str = ''
    track.tags.each do |tag|
      str += content_tag :span, tag.name, class: 'label track_tag', style: "background-color: #{tag.color}"
    end
    if track.title.size > max_len
      str += content_tag :span, truncate(track.title, length: max_len), data: { toggle: 'tooltip' }, title: track.title
    else
      str += track.title
    end
    str.html_safe
 end
  
end
