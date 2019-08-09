# frozen_string_literal: true
module NavigationHelper
  def global_nav # rubocop:disable Metrics/AbcSize
    str = ''
    global_nav_items.each do |name, props|
      css = ''
      css = 'active' if (@ambiguity_controller || params[:controller]).in?(props[1])
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
      str += nav_link(name, props, css, x)

      next unless /active/.match?(css)
      pos = x + 20
      str += nav_indicators(pos)
    end

    str.html_safe
  end

  def category_select(form_object, categories, group_names, field_name, value)
    common_options = [
      :id, :name,
      { prompt: true, name: field_name, selected: value },
      { class: 'form-control', name: field_name }
    ]
    if group_names.size > 1
      form_object.grouped_collection_select(
        :category_id, group_names,
        ->(group_name) { categories.where(group_name: group_name) },
        ->(group_name) { group_name || 'Other' },
        *common_options
      )
    else
      form_object.collection_select(:category_id, categories, *common_options)
    end
  end

  def nav_link(name, props, css, margin)
    content_tag(
      :div,
      link_to(name, props.first, class: "global_link #{css}"),
      class: 'link_container',
      style: "margin-left: #{margin}px;"
    )
  end

  def nav_indicators(pos)
    content_tag(:div, nil, class: 'nav_indicator', style: "margin-left: #{pos}px;") +
      content_tag(:div, nil, class: 'nav_indicator2', style: "margin-left: #{pos}px;")
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
    FIRST_CHAR_LIST.each_with_index do |char, idx|
      css = 'char_link'
      css += ' active' if active_for_char?(current_item, char, idx)
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
    char == '#' && (current_item.try(:name)&.first =~ /\d/ ||
      current_item.try(:title)&.first =~ /\d/)
  end

  def char_starts_name_or_title?(current_item, char)
    char.in?([current_item.try(:name)&.first, current_item.try(:title)&.first])
  end

  def default_char?(current_item, _char, idx)
    (params[:char].nil? && current_item.nil? && idx.zero?)
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
        style = i + 1 == years.size ? 'margin-right: 26px' : ''
        css = year == params[:slug] ? 'active' : ''
        str += link_to_year(year, css, style)
      end
    end
    str.html_safe
  end

  def link_to_year(year, css, style)
    link_to (year == '1983-1987' ? '83-87' : year[2..3]), "/#{year}", class: css, style: style
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

  def year_context?
    params[:controller] == 'years' || @ambiguity_controller == 'years'
  end

  def venue_context?
    params[:controller] == 'venues' || @ambiguity_controller == 'venues'
  end

  def song_context?
    params[:controller] == 'songs' || @ambiguity_controller == 'songs'
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
