module FilterHelper
  def filter_title(param_name, items)
    item = items.find { |_k, v| params[param_name] == v }&.first&.html_safe
    item.presence || items.first.first.html_safe
  end

  def filter(param_name, items) # rubocop:disable Metrics/AbcSize
    skippables = %w[controller action name t slug] + [param_name.to_s]
    items.map do |k, v|
      link = params[param_name] == v ? "<strong>#{k}</strong>" : k
      param_str = "?#{param_name}=#{CGI.escape(v)}"
      params.each do |key, val|
        next if key.in?(skippables)
        param_str += "&#{key}=#{val}" if val.present?
      end
      tag.li(link_to(link.html_safe, param_str))
    end.join.html_safe
  end

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

  def sort_songs_title(items)
    items.each_with_index do |(key, val), i|
      return key.html_safe if (i.zero? && params[:sort].empty?) ||
                              params[:sort] == val
    end
  end

  def show_sort_items
    {
      'Reverse Date' => 'date desc',
      'Date' => 'date asc',
      'Likes' => 'likes',
      'Duration' => 'duration'
    }
  end

  def my_track_sort_items
    { 'Title' => 'title' }.merge(track_sort_items)
  end

  def track_sort_items
    {
      'Reverse Date' => 'shows.date desc',
      'Date' => 'shows.date asc',
      'Likes' => 'likes',
      'Duration' => 'duration'
    }
  end

  def songs_and_venues_sort_items
    {
      'Title' => 'title',
      'Track Count' => 'performances'
    }
  end

  def tag_sort_items
    {
      'Name' => 'name',
      'Track Count' => 'tracks_count',
      'Show Count' => 'shows_count'
    }
  end

  def venues_sort_items
    {
      'Name' => 'name',
      'Show Count' => 'performances'
    }
  end

  def stored_playlist_sort_items
    {
      'Name' => 'name',
      'Duration' => 'duration'
    }
  end

  def song_track_tag_items(song)
    tag_data =
      song.tracks
          .joins(:tags)
          .group('tags.name', 'tags.slug')
          .order('tags.name')
          .pluck('tags.name', 'tags.slug', 'COUNT(tags.id)')
    tag_filter_options(tag_data)
  end

  # Use Ruby for tag counts because shows.order_values may take different forms
  # and GROUP_BY requires all columns in ORDER BY
  def shows_tag_items(shows) # rubocop:disable Metrics/AbcSize
    tag_data = shows.includes(:tags).flat_map(&:tags)
    grouped_tags = tag_data.each_with_object(Hash.new { |h, k| h[k] = { count: 0 } }) do |tag, hash|
      key = [tag.name, tag.slug]
      hash[key][:count] += 1
    end
    tag_data_array = grouped_tags.map do |(name, slug), data|
      [name, slug, data[:count]]
    end
    tag_data_array.uniq!
    tag_filter_options(tag_data_array)
  end

  def tag_filter_options(tag_data)
    items = { 'Any Tag' => 'all' }
    tag_data.each do |name, slug, count|
      items["#{name} (#{count})"] = slug
    end
    items
  end
end
