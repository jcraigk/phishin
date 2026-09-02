class Admin::PnetTagCheckJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      admin_job.update!(message: "Comparing the Phish.net setlist", progress: 5)
      setlist_lines = setlist_conflicts(show)

      admin_job.update!(message: "Checking the Phish.net Tease Chart", progress: 30)
      chart = TeaseChartSyncService.new(
        start_date: show.date.to_s, end_date: show.date.to_s
      )
      chart.call

      admin_job.update!(message: "Analyzing Phish.net setlist notes", progress: 60)
      notes = TeaseSyncService.new(date: show.date.to_s)
      notes.call

      admin_job.payload["report"] = build_report(setlist_lines, chart, notes)
      admin_job.save!
    end
  end

  private

  def build_report(setlist_lines, chart, notes)
    sections = []
    sections << section("Setlist conflicts with Phish.net", setlist_lines)
    sections << section(
      "Suggested additions from the Tease Chart",
      chart.proposed_rows.map { |p| "#{p[:track].title}: #{p[:note]}" }
    )
    sections << section(
      "Suggested additions from setlist notes",
      notes.proposed_rows.map { |p| "#{p[:track].title}: #{p[:note]}" }
    )
    sections << section(
      "Tagged teases not found in setlist notes (review for removal)",
      notes.unconfirmed
    )
    unmatched = chart.unmatched.map { |e| "#{e[:song]}: #{e[:note]} (#{e[:reason]})" } +
                notes.unmatched.map { |e| "#{e[:song]}: #{e[:tease]} (no track matched)" }
    sections << section("Mentioned but no track matched", unmatched)
    sections.join("\n\n")
  end

  def section(title, lines)
    body = lines.any? ? lines.map { |line| "  #{line}" }.join("\n") : "  (none)"
    "#{title}:\n#{body}"
  end

  def setlist_conflicts(show)
    info = ShowImporter::ShowInfo.new(show.date.to_s)
    pnet = info.songs.keys.sort.map do |position|
      { title: info.songs[position], set: info.sets[position] }
    end
    local = show.tracks.includes(:songs).order(:position).map do |track|
      {
        title: track.title,
        set: track.set.to_s.upcase,
        songs: track.songs.map(&:title)
      }
    end
    compare_setlists(pnet, local)
  rescue ShowImporter::ShowInfo::NotFoundError
    [ "Show not found on Phish.net" ]
  end

  def compare_setlists(pnet, local)
    lines = []
    used = Array.new(local.size, false)
    pnet.each do |entry|
      at = local.each_index.find { |i| !used[i] && covers?(local[i], entry[:title]) } ||
           local.each_index.find { |i| covers?(local[i], entry[:title]) }
      if at.nil?
        lines << "Missing here: #{entry[:title]} (#{set_label(entry[:set])})"
        next
      end
      used[at] = true
      match = local[at]
      if entry[:set].present? && match[:set] != entry[:set]
        lines << "Set mismatch: #{match[:title]} is #{set_label(match[:set])} here, " \
                 "#{set_label(entry[:set])} on Phish.net"
      end
    end
    local.each_with_index do |track, i|
      next if used[i]
      lines << "Not on Phish.net: #{track[:title]} (#{set_label(track[:set])})"
    end
    lines.uniq
  end

  def covers?(track, pnet_title)
    target = normalize(pnet_title)
    title = normalize(track[:title])
    return true if title == target || title.include?(target)
    track[:songs].any? { |song| normalize(song) == target }
  end

  def normalize(title)
    title.to_s.downcase.gsub(/[^a-z0-9 >]/, "").squish
  end

  def set_label(set)
    SET_NAMES[set.to_s] || set.to_s.presence || "no set"
  end
end
