# frozen_string_literal: true
module SortHelper
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
      '<i class="icon-time"></i> Reverse Date' => 'date desc',
      '<i class="icon-time"></i> Date' => 'date asc',
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
      '<i class="icon-time"></i> Duration' => 'duration',
      '<i class="icon-user"></i> Author' => 'username'
    }
  end
end
