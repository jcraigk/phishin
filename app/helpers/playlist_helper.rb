# frozen_string_literal: true
module PlaylistHelper
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
    tag.li(link_to(link.html_safe, param_str))
  end

  def playlist_filter_link_title(key, val, idx)
    if (idx.zero? && params[:filter].blank?) ||
       params[:filter] == val
      "<strong>#{key}</strong>".html_safe
    else
      key
    end
  end
end
