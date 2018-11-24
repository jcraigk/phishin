# frozen_string_literal: true
module NavigationHelper
  def global_nav
    str = ''
    global_nav_items.each do |name, props|
      css = ''
      css = 'active' if (@ambiguous_controller || params[:controller]).in?(props[1])
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

  def sub_nav
    if year_context?
      years_sub_links
    elsif venue_context?
      first_char_sub_links(venues_path, @venue)
    elsif song_context?
      first_char_sub_links(songs_path, @song)
    elsif top_liked_context?
      top_liked_sub_links
    elsif playlist_context?
      content_tag(:div, id: 'playlist_subnav_container') { playlists_sub_links }
    end
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

  def global_nav_items
    {
      'Years' => [eras_path, %w[years], 263],
      'Venues' => [venues_path, %w[venues], 327],
      'Songs' => [songs_path, %w[songs], 390],
      'Map' => [default_map_path, %w[map], 448],
      'Top 40' => [top_shows_path, %w[top_shows top_tracks], 504],
      'Playlists' => [active_playlist_path, %w[playlists], 570],
      'Tags' => [tags_path, %w[tags], 630]
    }
  end

  def year_context?
    params[:controller] == 'years' || @ambiguous_controller == 'years'
  end

  def venue_context?
    params[:controller] == 'venues' || @ambiguous_controller == 'venues'
  end

  def song_context?
    params[:controller] == 'songs' || @ambiguous_controller == 'songs'
  end

  def top_liked_context?
    params[:controller].in?(%w[top_shows top_tracks])
  end

  def playlist_context?
    params[:controller] == 'playlists'
  end

  def top_liked_sub_links
    nav_items = {
      'Top 40 Shows' => [top_shows_path, %w[top_shows]],
      'Top 40 Tracks' => [top_tracks_path, %w[top_tracks]]
    }
    str = ''
    nav_items.each do |name, props|
      css = ''
      css = 'active' if params[:controller].in?(props[1])
      str += link_to name, props[0], class: css
    end
    str.html_safe
  end
end
