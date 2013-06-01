module ApplicationHelper
  
  def sort_songs_and_venues_links(item_hash)
    str = ''
    item_hash.each do |key, val|
      link = params[:sort] == val ? "<strong>#{key}</strong>" : key
      str += content_tag :li, link_to(link.html_safe, "?char=#{params[:char]}&sort=#{CGI::escape(val)}")
    end
    str.html_safe
  end
  
  def first_char_sub_links(base_url, current_item=nil)
    str = ''
    FIRST_CHAR_LIST.each_with_index do |char, i|
      css = 'char_link'
      css += ' active' if params[:char] == char or 
        (params[:char].nil? and current_item.nil? and i == 0) or 
        (current_item and defined?(current_item.title) and current_item.title[0] == char) or
        (current_item and defined?(current_item.name) and current_item.name[0] == char)
      str += link_to char, "#{base_url}?char=#{CGI::escape(char)}", class: css
    end
    str.html_safe
  end
  
  def top_liked_sub_links
    nav_items = {
      'Top Shows' => [top_shows_path, ['top_liked_shows']],
      'Top Tracks' => [top_tracks_path, ['top_liked_tracks']],
    }
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[1].include?(params[:action])
      str += link_to name, properties[0], class: css
    end
    str.html_safe
  end
  
  def playlists_sub_links
    nav_items = {
      'Active' => [active_playlist_path, ['active_playlist']],
      'Saved' => [saved_playlists_path, ['saved_playlists']],
    }
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[1].include?(params[:action])
      str += link_to name, properties[0], class: css
    end
    str.html_safe
  end
  
  def years_sub_links
    years = [
      [
        '12' => [['2012'], '2012'],
        '11' => [['2011'], '2011'],
        '10' => [['2010'], '2010'],
        '09' => [['2009'], '2009']
      ],
      [
        '04' => [['2004'], '2004'],
        '03' => [['2003'], '2003'],
        '02' => [['2002'], '2002'],
      ],
      [
        '00' => [['2000'], '2004'],
        '99' => [['1999'], '1999'],
        '98' => [['1998'], '1998'],
        '97' => [['1997'], '1997'],
        '96' => [['1996'], '1996'],
        '95' => [['1995'], '1995'],
        '94' => [['1994'], '1994'],
        '93' => [['1993'], '1993'],
        '92' => [['1992'], '1992'],
        '91' => [['1991'], '1991'],
        '90' => [['1990'], '1990'],
        '89' => [['1989'], '1989'],
        '88' => [['1988'], '1988'],
        '87-83' => [['1987', '1986', '1985', '1984', '1987 - 1983'], '1987-1983'],
      ]
    ]
    str = ''
    years.each do |year_group|
      year_group.each do |year_hash|
        i = 0
        year_hash.each do |name, properties|
          style = ''
          style = 'margin-right: 26px' if i + 1 == year_hash.size
          css = ''
          css = 'active' if properties[0].include?(@title)
          # raise @title.inspect
          str += link_to name, "/#{properties[1]}", class: css, style: style
          i += 1
        end
        
      end
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
        "%dd %dh %dm" % [days, hours, minutes]
      elsif hours > 0
        "%dh %dm" % [hours, minutes]
      else
        "%dm %ds" % [minutes, seconds]
      end
    else
      if days > 0
        "%d:%02d:%02d:%02d" % [days, hours, minutes, seconds]
      elsif hours > 0
        "%d:%02d:%02d" % [hours, minutes, seconds]
      else
        "%d:%02d:%02d" % [minutes, seconds]
      end
    end
  end
  
  def global_nav_links
    nav_items = {
      'Years' => [years_path, ['years', 'year']],
      'Venues' => [venues_path, ['venues', 'venue']],
      'Songs' => [songs_path, ['songs', 'song']],
      'Map' => ['/map?map_term=Burlington%20VT&distance=250', ['map']],
      'Likes' => [top_shows_path, ['top_liked_shows', 'top_liked_tracks']],
      'Playlists' => [active_playlist_path, ['active_playlist', 'saved_playlists']]
    }
    x = 176
    x_step = 70
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[1].include?(params[:action]) or properties[1].include?(@controller_action)
      str += content_tag :div, (link_to name, properties[0], class: "global_link #{css}"), class: 'link_container', style: "margin-left: #{x}px;"
      if css == 'active'
        pos = x + 20
        str += content_tag :div, nil, class: 'nav_indicator', style: "margin-left: #{pos}px;"
        str += content_tag :div, nil, class: 'nav_indicator2', style: "margin-left: #{pos}px;"
      end
      x += x_step
    end
    str.html_safe
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
    show_abbrev ? show.date.strftime("%b %-d") : show.date.strftime("%-m.%-d.%y")
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
