module ApplicationHelper
  
  def duration_readable(ms)
    "%d:%02d" % [ms / 60000, ms % 60000 / 1000]
  end

  def index_nav_button(name, path)
    link_to (content_tag 'button', name, class: "btn #{current_nav_class(path)}"), path
  end
  
  private
  
  def current_nav_class(path)
    "btn-primary active" if current_page?(path)
  end
  
end
