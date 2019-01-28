# frozen_string_literal: true
module TagHelper
  def display_tag_instances(tag_instances, css_class = 'show_tag_container', context = 'show')
    tag_groups =
      tag_instances.sort_by { |t| [t.tag.priority, t.tag.try(:starts_at_second)] }
                   .group_by { |t| t.tag.name }
    return unless tag_groups.any?

    str = "<span class=\"#{css_class}\">"
    tag_groups.each { |group| str += tag_stack_label(group, context) }
    str += '</span>'

    str.html_safe
  end

  def tag_stack_label(tag_stack, context = 'show')
    title = tag_stack.first
    tag_instances = tag_stack.second
    first_instance = tag_instances.first
    link_to tag_path(first_instance.tag.slug, entity: context) do
      content_tag(
        :span,
        stack_title(tag_instances),
        class: 'label tag_label',
        title: tooltip_for_tag_instances(tag_instances),
        style: "background-color: #{first_instance.tag.color}",
        data: { html: true }
      )
    end
  end

  def stack_title(tag_instances)
    str = tag_instances.first.tag.name
    str += " (#{tag_instances.size})" if tag_instances.size >= 2
    str
  end

  def tag_label(tag, css_class = '')
    content_tag(
      :span,
      tag.name,
      class: "label tag_label #{css_class}",
      style: "background-color: #{tag.color}"
    )
  end

  def tooltip_for_tag_instances(tag_instances)
    title = ''

    tag_instances.each_with_index do |t, idx|
      if t.try(:starts_at_second)&.present?
        title += "Starts at #{tag_timestamp(t&.starts_at_second)}<br><br>"
      end
      if t.try(:ends_at_second)&.present?
        title += "Ends at #{tag_timestamp(t&.ends_at_second)}<br><br>"
      end
      title += wrapped_str(t.notes) if t.notes.present?
      if t.try(:transcript)&.present?
        title += "<br><br>-TRANSCRIPT-<br> #{wrapped_str(t.transcript)}"
      end

      title += '<br>-------------------<br>' unless idx == tag_instances.size - 1
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
