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
        (char == '#' and defined?(current_item.name) and current_item.name[0] =~ /\d/) or
        (char == '#' and defined?(current_item.title) and current_item.title[0] =~ /\d/) or
        (current_item and defined?(current_item.title) and current_item.title[0] == char) or
        (current_item and defined?(current_item.name) and current_item.name[0] == char)
      str += link_to char, "#{base_url}?char=#{CGI::escape(char)}", class: css
    end
    str.html_safe
  end
  
  def top_liked_sub_links
    nav_items = {
      'Top 40 Shows' => [top_shows_path, ['top_liked_shows']],
      'Top 40 Tracks' => [top_tracks_path, ['top_liked_tracks']]
    }
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[1].include?(params[:action])
      str += link_to name, properties[0], class: css
    end
    str.html_safe
  end
  
  def user_sub_links
    nav_items = {
      'My Shows' => [my_shows_path, false, ['my_shows']],
      'My Tracks' => [my_tracks_path, false, ['my_tracks']],
      'Change Password' => [edit_user_registration_path, true, ['edit']],
      'Logout' => [destroy_user_session_path, true, ['nothing']]
    }
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[2].include?(params[:action])
      css += ' non-remote' if properties[1]
      if name == 'Logout'
        str += link_to name, properties[0], class: css, method: :delete
      else
        str += link_to name, properties[0], class: css
      end
    end
    str.html_safe
  end

  def user_dropdown_links
    nav_items = {
      'My Shows' => [my_shows_path, false, ['my_shows']],
      'My Tracks' => [my_tracks_path, false, ['my_tracks']],
      'Change Password' => [edit_user_registration_path, true, ['edit']],
      'Logout' => [destroy_user_session_path, true, ['nothing']]
    }
    str = ''
    nav_items.each do |name, properties|
      str += '<li>'
      if name == 'Logout'
        str += link_to name, properties[0], method: :delete, class: 'non-remote'
      else
        str += link_to name, properties[0], class: 'non-remote'
      end
      str += '</li>'
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
    str = ''
    Hash[ERAS.to_a.reverse].each do |era, years|
      years.reverse.each_with_index do |year, i|
        style = ''
        style = 'margin-right: 26px' if i + 1 == years.size
        css = ''
        css = 'active' if year == @title
        str += link_to (year == '1983-1987' ? '83-87' : year[2..3]), "/#{year}", class: css, style: style
      end
    end
    str.html_safe
  end
  
  def will_paginate_simple(collection)
    will_paginate collection, inner_window: 2, outer_window: 0, previous_label: '<<', next_label: '>>', params: [:per_page, :t]
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
        "%d:%02d" % [minutes, seconds]
      end
    end
  end
  
  def global_nav_links
    nav_items = {
      # 'userbox' => [nil, ['my_shows', 'my_tracks', 'edit'], 14],
      'Years' => [years_path, ['years', 'year'], 283],
      'Venues' => [venues_path, ['venues', 'venue'], 347],
      'Songs' => [songs_path, ['songs', 'song'], 410],
      'Map' => ['/map?map_term=Burlington%20VT&distance=10', ['map'], 468],
      'Top 40' => [top_shows_path, ['top_liked_shows', 'top_liked_tracks'], 524],
      'Playlists' => [active_playlist_path, ['active_playlist', 'saved_playlists'], 590]
    }
    str = ''
    nav_items.each do |name, properties|
      css = ''
      css = 'active' if properties[1].include?(params[:action]) or properties[1].include?(@controller_action)
      if name == 'userbox'
        css += ' user_control'
        if user_signed_in?
          properties[0] = my_shows_path
          name = current_user.username
        else
          properties[0] = new_user_session_path
          name = 'Sign up!'
          css += ' non-remote'
        end
      end
      x = properties[2]
      str += content_tag :div, (link_to name, properties[0], class: "global_link #{css}"), class: 'link_container', style: "margin-left: #{x}px;"
      if css =~ /active/
        pos = x + 20
        str += content_tag :div, nil, class: 'nav_indicator', style: "margin-left: #{pos}px;"
        str += content_tag :div, nil, class: 'nav_indicator2', style: "margin-left: #{pos}px;"
      end
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
    show_abbrev ? show.date.strftime("%b %-d") : show.date.strftime("%Y.%m.%d")
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
    max_len = 70
    str = '<div class="track_tag_container">'
    track.tags.each do |tag|
      str += content_tag :span, tag.name, class: 'label track_tag', style: "background-color: #{tag.color}"
    end
    str += "</div>"
    if track.title.size > max_len
      str += content_tag :span, truncate(track.title, length: max_len), data: { toggle: 'tooltip' }, title: track.title
    else
      str += track.title
    end
    
    str.html_safe
  end

   def taper_notes_or_missing(show)
     show.taper_notes.present? ? show.taper_notes.html_safe : 'No taper notes present for this show'.html_safe
   end
  
end
