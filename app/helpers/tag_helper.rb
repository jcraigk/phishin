# frozen_string_literal: true
module TagHelper
  def display_tag_instances(
    tag_instances,
    short = false,
    css_class = 'show_tag_container',
    context = 'show'
  )
    tag_instances = tag_instances.sort_by { |t| t.tag.priority }
    str = "<span class=\"#{css_class}\">"
    if short
      if (count = tag_instances.count).positive?
        t = tag_instances.first
        str += tag_instance_label(t, context)
        str += '<span class="tags_plus">...</span>' if count > 1
      end
    else
      tag_instances.each { |ti| str += tag_instance_label(ti, context) }
    end
    str += '</span>'
    str.html_safe
  end

  def tag_instance_label(tag_instance, context = 'show')
    link_to tag_path(tag_instance.tag.slug, entity: context) do
      content_tag(
        :span,
        tag_instance.tag.name,
        class: 'label tag_label',
        title: title_for_tag_instance(tag_instance),
        style: "background-color: #{tag_instance.tag.color}",
        data: { html: true }
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

  def title_for_tag_instance(t)
    title = ''

    if t.try(:starts_at_second)&.present?
      title += "Starts at #{tag_timestamp(t&.starts_at_second)}<br><br>"
    end
    if t.try(:ends_at_second)&.present?
      title += "Ends at #{tag_timestamp(t&.ends_at_second)}<br><br>"
    end
    title += "#{wrapped_str(t.notes)}" if t.notes.present?
    if t.try(:transcript)&.present?
      title += "<br><br>-TRANSCRIPT-<br> #{wrapped_str(t.transcript)}"
    end

    title
  end

  def wrapped_str(str)
    word_wrap(str, line_width: 50).gsub("\n", '<br>')
  end

  def tag_timestamp(timestamp)
    duration_readable(timestamp * 1000, 'colons')
  end
end
