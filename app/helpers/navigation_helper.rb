module NavigationHelper
  def global_nav(controller) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    str = ""
    global_nav_items.each do |name, props|
      css = active_route?(controller, props[1]) ? "active" : nil
      if name == "userbox"
        css += " user_control"
        if logged_in?
          props[0] = my_shows_path
          name = current_user.username
        else
          props[0] = new_user_session_path
          name = "Sign up!"
          css += " non-remote"
        end
      end
      x = props[2]
      str += nav_link(name, props, css, x)

      next unless css&.include?("active")
      pos = x + 20
      str += nav_indicators(pos)
    end

    str.html_safe
  end

  def active_route?(controller, keyword)
    controller.in?(keyword) ||
      params[:controller].in?(keyword) ||
      params[:slug].in?(keyword)
  end

  def nav_link(name, props, css, margin)
    tag.div(
      link_to(name, props.first, class: "global_link #{css}"),
      class: "link_container",
      style: "margin-left: #{margin}px;"
    )
  end

  def nav_indicators(pos)
    tag.div(class: "nav_indicator", style: "margin-left: #{pos}px;") +
      tag.div(class: "nav_indicator2", style: "margin-left: #{pos}px;")
  end

  def sub_nav(controller, venue, song) # rubocop:disable Metrics/MethodLength
    if year_context?(controller)
      years_sub_links
    elsif venue_context?(controller)
      first_char_sub_links(venues_path, venue)
    elsif song_context?(controller)
      first_char_sub_links(songs_path, song)
    elsif top_liked_context?
      top_liked_sub_links
    elsif playlist_context?
      tag.div(id: "playlist_subnav_container") { playlists_sub_links }
    end
  end

  def first_char_sub_links(base_url, current_item = nil)
    str = ""
    FIRST_CHAR_LIST.each_with_index do |char, idx|
      css = "char_link"
      css += " active" if active_for_char?(current_item, char, idx)
      str += link_to char, "#{base_url}?char=#{CGI.escape(char)}", class: css
    end
    str.html_safe
  end

  def active_for_char?(current_item, char, idx)
    params[:char] == char ||
      default_char?(current_item, char, idx) ||
      char_is_number?(current_item, char) ||
      char_starts_name_or_title?(current_item, char)
  end

  def char_is_number?(current_item, char)
    char == "#" && (current_item.try(:name)&.first =~ /\d/ ||
      current_item.try(:title)&.first =~ /\d/)
  end

  def char_starts_name_or_title?(current_item, char)
    char.in?([ current_item.try(:name)&.first, current_item.try(:title)&.first ])
  end

  def default_char?(current_item, _char, idx)
    params[:char].nil? && current_item.nil? && idx.zero?
  end

  def global_nav_items
    {
      "Years" => [ eras_path, %w[years eras], 263 ],
      "Venues" => [ venues_path, %w[venues], 327 ],
      "Songs" => [ songs_path, %w[songs], 390 ],
      "Map" => [ default_map_path, %w[map], 448 ],
      "Top 40" => [ top_shows_path, %w[top_shows top_tracks], 504 ],
      "Playlists" => [ active_playlist_path, %w[playlists], 570 ],
      "Tags" => [ tags_path, %w[tags], 630 ],
      "Today" => [ "/today-in-history", %w[today today-in-history], 685 ]
    }
  end

  def user_dropdown_links
    {
      "My Shows" => [ my_shows_path, false, [ "my_shows" ] ],
      "My Tracks" => [ my_tracks_path, false, [ "my_tracks" ] ],
      "Change Password" => [ edit_user_registration_path, true, [ "edit" ] ],
      "Logout" => [ destroy_user_session_path, true, [ "nothing" ] ]
    }.map do |name, props|
      opts = { class: "non-remote" }
      opts[:method] = :delete if name == "Logout"
      tag.li(link_to(name, props.first, opts))
    end.join.html_safe
  end

  def playlists_sub_links
    {
      "Active" => [ active_playlist_path, [ "active" ] ],
      "Saved" => [ stored_playlists_path, [ "stored" ] ]
    }.map do |name, props|
      css = ""
      css = "active" if props.second.include?(params[:action])
      link_to(name, props.first, class: css)
    end.join.html_safe
  end

  def years_sub_links
    str = ""
    ERAS.to_a.reverse.to_h.each_value do |years|
      years.reverse.each_with_index do |year, i|
        style = i + 1 == years.size ? "margin-right: 15px" : ""
        css = year == params[:slug] ? "active" : ""
        str += link_to_year(year, css, style)
      end
    end
    str.html_safe
  end

  def link_to_year(year, css, style)
    link_to (year == "1983-1987" ? "83-87" : year[2..3]), "/#{year}", class: css, style:
  end

  def will_paginate_simple(collection)
    will_paginate(
      collection,
      inner_window: 2,
      outer_window: 0,
      previous_label: "<<",
      next_label: ">>",
      params: { per_page: params[:per_page], t: params[:t] }
    )
  end

  def year_context?(controller)
    params[:controller] == "years" || controller == "years"
  end

  def venue_context?(controller)
    params[:controller] == "venues" || controller == "venues"
  end

  def song_context?(controller)
    params[:controller] == "songs" || controller == "songs"
  end

  def top_liked_context?
    params[:controller].in?(%w[top_shows top_tracks])
  end

  def playlist_context?
    params[:controller] == "playlists"
  end

  def top_liked_sub_links
    nav_items = {
      "Top 40 Shows" => [ top_shows_path, %w[top_shows] ],
      "Top 40 Tracks" => [ top_tracks_path, %w[top_tracks] ]
    }
    nav_items.map do |name, props|
      css = params[:controller].in?(props.second) ? "active" : ""
      link_to(name, props.first, class: css)
    end.join.html_safe
  end

  def single_page_link
    link_to "Single page", url_for(per_page: 100_000)
  end
end
