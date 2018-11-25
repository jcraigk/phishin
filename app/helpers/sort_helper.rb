# frozen_string_literal: true
module SortHelper
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

  def my_shows_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def my_tracks_sort_items
    {
      '<i class="icon-time"></i> Title' => 'title',
      '<i class="icon-time"></i> Reverse Date' => 'shows.date desc',
      '<i class="icon-time"></i> Date' => 'shows.date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def tag_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-list"></i> Number of Tracks' => 'tracks_count',
      '<i class="icon-list"></i> Number of Shows' => 'shows_count'
    }
  end

  def show_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-play-circle"></i> Duration' => 'duration'
    }
  end

  def song_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def songs_and_venues_sort_items
    {
      '<i class="icon-text-height"></i> Title' => 'title',
      '<i class="icon-list"></i> Number of Tracks' => 'performances'
    }
  end

  def venue_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def venues_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-list"></i> Number of Shows' => 'performances'
    }
  end

  def year_or_scope_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-play-circle"></i> Duration' => 'duration'
    }
  end

  def saved_playlist_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-time"></i> Duration' => 'duration'
    }
  end
end
