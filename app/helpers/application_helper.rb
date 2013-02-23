module ApplicationHelper
  
  def duration_readable(ms)
    "%d:%02d" % [ms / 60000, ms % 60000 / 1000]
  end

  def index_nav_button(name, path)
    link_to (content_tag 'button', name, class: "btn #{current_nav_class(path)}"), path
  end
  
  def link_to_song(song)
    slug = song.aliased_song ? "/#{song.aliased_song.slug}" : "/#{song.slug}"
    link_to song.title, slug
  end
  
  def performances_or_alias_link(song)
    song.aliased_song ? (link_to "alias for #{song.aliased_song.title}", "#{song.aliased_song.slug}", class: :alias_for) : song.tracks_count
  end
  
  private
  
  def current_nav_class(path)
    "btn-primary active" if current_page?(path) or (path == '/years' and request.fullpath == '/')
  end
  
end
