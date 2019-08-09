# frozen_string_literal: true
module TagHelper
  def display_tag_instances(tag_instances, css_class = 'show_tag_container')
    tag_groups =
      tag_instances.sort_by { |t| [t.tag.priority, t.tag.try(:starts_at_second)] }
                   .group_by { |t| t.tag.name }
    return unless tag_groups.any?

    str = "<span class=\"#{css_class}\">"
    tag_groups.each { |group| str += tag_stack_label(group) }
    str += '</span>'

    str.html_safe
  end

  def tag_stack_label(tag_stack)
    tag_instances = tag_stack.second
    first_instance = tag_instances.first
    link_to '#' do
      content_tag(
        :span,
        stack_title(tag_instances),
        class: 'label tag_label',
        title: tooltip_for_tag_stack(tag_instances),
        style: "background-color: #{first_instance.tag.color}",
        data: {
          html: true,
          detail_title: detail_title(tag_instances),
          detail: tooltip_for_tag_stack(tag_instances, true)
        }
      )
    end
  end

  def detail_title(tag_instances)
    tag_instance = tag_instances.first
    if tag_instance.is_a?(TrackTag)
      "#{tag_label(tag_instance.tag, 'detail_tag_label')}" \
      "<br>#{tag_instance.track.show.date_with_dots} #{tag_instance.track.title}"
    else
      "#{tag_label(tag_instance.tag, 'detail_tag_label')}<br>#{tag_instance.show.date_with_dots}"
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

  def tooltip_for_tag_stack(tag_instances, include_transcript = false)
    title = ''

    tag_instances.each_with_index do |t, idx|
      title += tag_notes(t)
      title += transcript_or_link(t, title, include_transcript)
      title += '<br>' unless idx == tag_instances.size - 1
    end

    title = tag_instances.first.tag.description if title.blank?
    title
  end

  def tag_notes(tag)
    return '' if tag.notes.blank?
    "#{tag.notes} #{time_range(tag)}".strip
  end

  def transcript_or_link(tag, title, include_transcript)
    return '' if tag.try(:transcript).blank?

    str = ''

    if include_transcript
      str += '<br><br>' if title.present?
      return str + "<strong>TRANSCRIPT</strong><br><br> #{tag.transcript.gsub("\n", '<br>')}"
    end

    str += '<br>' if title.present?
    str + '[CLICK FOR TRANSCRIPT]'
  end

  def time_range(tag_instance)
    return unless start_timestamp(tag_instance) || end_timestamp(tag_instance)

    if start_timestamp(tag_instance) && end_timestamp(tag_instance)
      "between #{start_timestamp(tag_instance)} and #{end_timestamp(tag_instance)}"
    elsif start_timestamp(tag_instance)
      "at #{start_timestamp(tag_instance)}"
    end
  end

  def start_timestamp(tag_instance)
    return unless tag_instance.try(:starts_at_second)
    tag_timestamp(tag_instance.starts_at_second)
  end

  def end_timestamp(tag_instance)
    return unless tag_instance.try(:ends_at_second)
    tag_timestamp(tag_instance.ends_at_second)
  end

  def tag_timestamp(timestamp)
    duration_readable(timestamp * 1000, 'colons')
  end
end
