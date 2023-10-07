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

  def tag_stack_label(tag_stack) # rubocop:disable Metrics/MethodLength
    tag_instances = tag_stack.second.sort_by { |t| t.try(:starts_at_second) || 0 }
    first_instance = tag_instances.first
    link_to '#' do
      tag.span(
        stack_title(tag_instances),
        class: 'label tag_label',
        title: tooltip_for_tag_stack(tag_instances),
        style: "background-color: #{first_instance.tag.color}",
        data: {
          html: true,
          detail_title: detail_title(tag_instances),
          detail: tooltip_for_tag_stack(tag_instances, detail: true)
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

  def tag_label(tag_record, css_class = '')
    tag.span(
      tag_record.name,
      class: "label tag_label #{css_class}",
      style: "background-color: #{tag_record.color}"
    )
  end

  def tooltip_for_tag_stack(tag_instances, detail: false)
    title = ''

    tag_instances.each_with_index do |t, idx|
      title += tag_notes(t, detail:)
      title += transcript_or_link(t, title) if detail
      title += '<br>' unless idx == tag_instances.size - 1
    end

    title = tag_instances.first.tag.description if title.blank?
    title
  end

  def tag_notes(tag_instance, detail:)
    return '' if tag_instance.notes.blank?
    str = tag_instance.notes
    str += " #{time_range(tag_instance, detail:)}"
    str.strip
  end

  def transcript_or_link(tag_instance, title)
    return '' if tag_instance.try(:transcript).blank?
    str = '<br><br>' if title.present?
    str + "<strong>TRANSCRIPT</strong><br><br> #{tag_instance.transcript.gsub("\n", '<br>')}"
  end

  def time_range(tag_instance, detail:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return unless start_timestamp(tag_instance) || end_timestamp(tag_instance)

    starts_at = start_timestamp(tag_instance)
    url = "/#{tag_instance.track.show.date}/#{tag_instance.track.slug}?t=#{starts_at}"
    if start_timestamp(tag_instance) && end_timestamp(tag_instance)
      range = "#{starts_at} and #{end_timestamp(tag_instance)}"
      str = 'between '
      str += detail ? link_to(range, url) : range
    elsif start_timestamp(tag_instance)
      str = 'at '
      str += detail ? link_to(starts_at, url) : starts_at
    end
    str
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
