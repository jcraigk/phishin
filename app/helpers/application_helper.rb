# frozen_string_literal: true
module ApplicationHelper
  def clear_both
    content_tag :div, '', style: 'clear: both;'
  end

  def shows_for_year(year)
    if year == '1983-1987'
      Show.avail.between_years('1983', '1987').includes(:venue)
    else
      Show.avail.during_year(year).includes(:venue)
    end
  end

  def total_hours_of_music
    (Show.avail.map(&:duration).inject(0, &:+) / 3_600_000).round
  end

  def sort_songs_and_venues_links(item_hash)
    str = ''
    item_hash.each do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      str += content_tag(
        :li,
        link_to(
          link.html_safe,
          "?char=#{params[:char]}&sort=#{CGI.escape(v)}"
        )
      )
    end
    str.html_safe
  end

  def sort_tags_title(item_hash)
    item_hash.each_with_index do |(key, val), idx|
      if (idx.zero? && params[:filter].blank?) ||
         params[:filter] == val
        return "<strong>#{key}</strong>".html_safe
      end
    end
  end

  def sort_tags_links(item_hash)
    str = ''
    item_hash.each do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      str += content_tag :li, link_to(link.html_safe, "?sort=#{CGI.escape(v)}")
    end
    str.html_safe
  end

  def first_char_sub_links(base_url, current_item = nil)
    str = ''
    FIRST_CHAR_LIST.each_with_index do |char, i|
      css = 'char_link'
      css += ' active' if
        params[:char] == char ||
        (params[:char].nil? && current_item.nil? && i.zero?) ||
        (char == '#' && defined?(current_item.name) && current_item.name[0] =~ /\d/) ||
        (char == '#' && defined?(current_item.title) && current_item.title[0] =~ /\d/) ||
        (current_item && defined?(current_item.title) && current_item.title[0] == char) ||
        (current_item && defined?(current_item.name) && current_item.name[0] == char)
      str += link_to char, "#{base_url}?char=#{CGI.escape(char)}", class: css
    end
    str.html_safe
  end

  def top_liked_sub_links
    nav_items = {
      'Top 40 Shows' => [top_shows_path, ['top_liked_shows']],
      'Top 40 Tracks' => [top_tracks_path, ['top_liked_tracks']]
    }
    str = ''
    nav_items.each do |name, props|
      css = ''
      css = 'active' if props[1].include?(params[:action])
      str += link_to name, props[0], class: css
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
    nav_items.each do |name, props|
      str += '<li>'
      str +=
        if name == 'Logout'
          link_to(name, props[0], method: :delete, class: 'non-remote')
        else
          link_to(name, props[0], class: 'non-remote')
        end
      str += '</li>'
    end
    str.html_safe
  end

  def playlists_sub_links
    nav_items = {
      'Active' => [active_playlist_path, ['active_playlist']],
      'Saved' => [saved_playlists_path, ['saved_playlists']]
    }
    str = ''
    nav_items.each do |name, props|
      css = ''
      css = 'active' if props[1].include?(params[:action])
      str += link_to name, props[0], class: css
    end
    str.html_safe
  end

  def years_sub_links
    str = ''
    Hash[ERAS.to_a.reverse].each do |_era, years|
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
    will_paginate(
      collection,
      inner_window: 2,
      outer_window: 0,
      previous_label: '<<',
      next_label: '>>',
      params: {
        per_page: params[:per_page],
        t: params[:t]
      }
    )
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

  def global_nav_links
    str = ''
    global_nav_items.each do |name, props|
      css = ''
      css = 'active' unless ([params[:action], @controller_action] & props[1]).empty?
      if name == 'userbox'
        css += ' user_control'
        if user_signed_in?
          props[0] = my_shows_path
          name = current_user.username
        else
          props[0] = new_user_session_path
          name = 'Sign up!'
          css += ' non-remote'
        end
      end
      x = props[2]
      str +=
        content_tag(
          :div,
          link_to(name, props.first, class: "global_link #{css}"),
          class: 'link_container',
          style: "margin-left: #{x}px;"
        )
      next unless /active/.match?(css)
      pos = x + 20
      str += content_tag(:div, nil, class: 'nav_indicator', style: "margin-left: #{pos}px;")
      str += content_tag(:div, nil, class: 'nav_indicator2', style: "margin-left: #{pos}px;")
    end
    str.html_safe
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

  private

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
    exempt_controllers.include?(controller_name)
  end

  def devise_controllers
    %w[
      sessions registrations confirmations
      passwords unlocks omniauth_callbacks
    ]
  end

  def special_controllers
    %w[downloads errors]
  end

  def exempt_controllers
    devise_controllers + special_controllers
  end

  def taper_notes_or_missing(show)
    show.taper_notes.present? ? CGI.escapeHTML(show.taper_notes) : 'No taper notes present for this show'.html_safe
  end

  def pluralize_with_delimiter(count, word)
    "#{number_with_delimiter(count)} #{word.pluralize(count)}".html_safe
  end

  def display_tag_instances(tag_instances, short = false, css_class = 'show_tag_container')
    str = "<span class=\"#{css_class}\">"
    if short
      if (count = tag_instances.count).positive?
        tag_instance = tag_instances.first
        str += tag_instance_label(tag_instance)
        str += '<span class="tags_plus">...</span>' if count > 1
      end
    else
      tag_instances.each { |t| str += tag_instance_label(t) }
    end
    str += '</span>'
    str.html_safe
  end

  def tag_instance_label(tag_instance, css_class = '')
    link_to tag_path(name: tag_instance.tag.name.downcase) do
      content_tag(
        :span,
        tag_instance.tag.name,
        class: "label tag_label #{css_class}",
        title: tag_instance.notes,
        style: "color: #{contrasting_color(tag_instance.tag.color)}; background-color: #{tag_instance.tag.color}"
      )
    end.html_safe
  end

  def tag_label(tag, css_class = '')
    link_to tag_path(name: tag.name.downcase) do
      content_tag(
        :span,
        tag.name,
        class: "label tag_label #{css_class}",
        style: "color: #{contrasting_color(tag.color)}; background-color: #{tag.color}"
      )
    end
  end

  def contrasting_color(color)
    color_str = color.clone
    color_str[0] = ''
    rgb_hex = color_str.scan(/../)
    sum = 0
    rgb_hex.each { |hex| sum += hex.hex }
    sum > 382 ? '#555555' : '#ffffff'
  end

  def global_nav_items
    {
      'Years' => [years_path, %w[years year], 263],
      'Venues' => [venues_path, %w[venues venue], 327],
      'Songs' => [songs_path, %w[songs song], 390],
      'Map' => [default_map_path, %w[map], 448],
      'Top 40' => [top_shows_path, %w[top_liked_shows top_liked_tracks], 504],
      'Playlists' => [active_playlist_path, %w[active_playlist saved_playlists], 570],
      'Tags' => [tags_path, %w[index selected_tag], 630]
    }
  end

  def default_map_path
    '/map?map_term=Burlington%20VT&distance=10'
  end

  def playlist_filter_hash
    {
      '<i class="icon icon-globe"></i> All' => 'all',
      '<i class="icon icon-user"></i> Only Mine' => 'mine',
      '<i class="icon icon-bookmark"></i> Only Phriends\'' => 'phriends'
    }
  end

  def playlist_filters
    str = ''
    playlist_filter_hash.each_with_index do |(key, val), idx|
      str += playlist_filter_link(key, val, idx)
    end

    str.html_safe
  end

  def selected_playlist_filter
    playlist_filter_hash.each do |k, v|
      return k.html_safe if params[:filter].blank? || params[:filter] == v
    end
  end

  def playlist_filter_link(key, val, idx)
    link = playlist_filter_link_title(key, val, idx)
    param_str = "/playlists?filter=#{CGI.escape(val)}"
    param_str += "&sort=#{params[:sort]}" if params[:sort]
    content_tag(:li, link_to(link.html_safe, param_str))
  end

  def playlist_filter_link_title(key, val, idx)
    if (idx.zero? && params[:filter].blank?) ||
       params[:filter] == val
      "<strong>#{key}</strong>".html_safe
    else
      key
    end
  end

  def sort_filter_link_title(items)
    items.each do |k, v|
      return k.html_safe if params[:sort] == v || params[:sort].blank?
    end
  end

  def sort_filter(items)
    str = ''
    items.each do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      param_str = "?sort=#{CGI.escape(v)}"
      params.each do |key, val|
        unless %w[controller action name t sort].include?(key)
          param_str += "&#{key}=#{val}" if val.present?
        end
      end

      str += content_tag :li, link_to(link.html_safe, param_str)
    end

    str.html_safe
  end

  def sort_songs_title(items)
    items.each_with_index do |(key, val), i|
      return key.html_safe if (i.zero? && params[:sort].empty?) ||
                              params[:sort] == val
    end
  end
end
