# frozen_string_literal: true
module TagHelper
  def display_tag_instances(tag_instances, short = false, css_class = 'show_tag_container')
    tag_instances = tag_instances.sort_by { |tag_instance| tag_instance.tag.priority }
    str = "<span class=\"#{css_class}\">"
    if short
      if (count = tag_instances.count).positive?
        tag_instance = tag_instances.first
        str += tag_instance_label(tag_instance)
        str += '<span class="tags_plus">...</span>' if count > 1
      end
    else
      tag_instances.each { |t| str += tag_instance_label(t) }
    end
    str += '</span>'
    str.html_safe
  end

  def tag_instance_label(tag_instance, css_class = '')
    link_to tag_path(tag_instance.tag.slug) do
      content_tag(
        :span,
        tag_instance.tag.name,
        class: "label tag_label #{css_class}",
        title: tag_instance.notes,
        style: "background-color: #{tag_instance.tag.color}"
      )
    end
  end

  def tag_label(tag, css_class = '')
    content_tag(
      :span,
      tag.name,
      class: "label tag_label #{css_class}",
      style: "background-color: #{tag.color}"
    )
  end
end
