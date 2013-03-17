module ApplicationHelper

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

  def index_nav_button(name, path, icon_css, other_path='')
    icon_css += " icon-white" if nav_active?(path) or nav_active?(other_path)
    link_to (content_tag 'button', "<i class=\"#{icon_css}\"></i> #{name}".html_safe, class: "btn #{current_nav_class(path, other_path)}"), path
  end
  
  def link_to_song(song)
    slug = song.aliased_song ? "/#{song.aliased_song.slug}" : "/#{song.slug}"
    link_to song.title, slug
  end
  
  def performances_or_alias_link(song, display_title=false)
    tracks_count = (display_title ? pluralize(song.tracks_count, 'track') : song.tracks_count)
    song.aliased_song ? (link_to "alias for #{song.aliased_song.title}", "#{song.aliased_song.slug}", class: :alias_for) : tracks_count
  end
  
  def likable(likable, like, size)
    likable_name = likable.class.name.downcase
    css = (like.present? ? [:like_toggle, :liked] : [:like_toggle])
    a = link_to '', 'null', data: { type: likable_name, id: likable.id}, class: css, title: "Click to Like or Unlike this #{likable_name}"
    span = content_tag :span, likable.likes_count
    str = content_tag :div, a + span, class: "likes_#{size}"
    str.html_safe
  end
  
  private
  
  def current_nav_class(path, other_path)
    "btn-primary active" if nav_active?(path) or nav_active?(other_path)
  end
  
  def nav_active?(path)
    current_page?(path) or (path == '/years' and request.fullpath == '/')
  end
  
  def linked_show_date(show)
    day_link = link_to show.date.strftime("%b %-d"), "/#{show.date.strftime("%B").downcase}-#{show.date.strftime("%-d")}"
    year_link = link_to show.date.strftime("%Y"), "/#{show.date.strftime("%Y")}"
    "#{day_link}, #{year_link}".html_safe
  end
  
end
