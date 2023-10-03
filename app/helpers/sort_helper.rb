module SortHelper
  def sort_songs_and_venues_links(item_hash)
    item_hash.map do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      tag.li(link_to(link.html_safe, "?char=#{params[:char]}&sort=#{CGI.escape(v)}"))
    end.join.html_safe
  end

  def sort_tags_title(item_hash)
    item_hash.each_with_index do |(key, val), idx|
      if (idx.zero? && params[:sort].blank?) ||
         params[:sort] == val
        return "<strong>#{key}</strong>".html_safe
      end
    end
  end

  def sort_tags_links(item_hash)
    str = ''
    item_hash.each do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      str += tag.li(link_to(link.html_safe, "?sort=#{CGI.escape(v)}"))
    end
    str.html_safe
  end

  def sort_filter_link_title(items)
    items.each do |k, v|
      return k.html_safe if params[:sort] == v || params[:sort].blank?
    end
    items.first.first.html_safe
  end

  def sort_filter(items)
    items.map do |k, v|
      link = params[:sort] == v ? "<strong>#{k}</strong>" : k
      param_str = "?sort=#{CGI.escape(v)}"
      params.each do |key, val|
        next if key.in?(%w[controller action name t sort])
        param_str += "&#{key}=#{val}" if val.present?
      end
      tag.li(link_to(link.html_safe, param_str))
    end.join.html_safe
  end

  def sort_songs_title(items)
    items.each_with_index do |(key, val), i|
      return key.html_safe if (i.zero? && params[:sort].empty?) ||
                              params[:sort] == val
    end
  end

  def show_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def my_track_sort_items
    { '<i class="icon-time"></i> Title' => 'title' }.merge(track_sort_items)
  end

  def track_sort_items
    {
      '<i class="icon-time"></i> Reverse Date' => 'shows.date desc',
      '<i class="icon-time"></i> Date' => 'shows.date asc',
      '<i class="icon-heart"></i> Likes' => 'likes',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end

  def songs_and_venues_sort_items
    {
      '<i class="icon-text-height"></i> Title' => 'title',
      '<i class="icon-list"></i> Track Count' => 'performances'
    }
  end

  def tag_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-list"></i> Track Count' => 'tracks_count',
      '<i class="icon-list"></i> Show Count' => 'shows_count'
    }
  end

  def venues_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-list"></i> Show Count' => 'performances'
    }
  end

  def stored_playlist_sort_items
    {
      '<i class="icon-text-height"></i> Name' => 'name',
      '<i class="icon-forward"></i> Duration' => 'duration'
    }
  end
end
