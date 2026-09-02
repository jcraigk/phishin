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
    local = show.tracks.order(:position).map do |track|
      { title: track.title, set: track.set.to_s.upcase }
    end
    compare_setlists(pnet, local)
  rescue ShowImporter::ShowInfo::NotFoundError
    [ "Show not found on Phish.net" ]
  end

  def compare_setlists(pnet, local)
    lines = []
    remaining = local.dup
    pnet.each do |entry|
      at = remaining.index { |t| covers?(t[:title], entry[:title]) }
      if at.nil?
        lines << "Missing here: #{entry[:title]} (#{set_label(entry[:set])})"
        next
      end
      match = remaining.delete_at(at)
      if entry[:set].present? && match[:set] != entry[:set]
        lines << "Set mismatch: #{match[:title]} is #{set_label(match[:set])} here, " \
                 "#{set_label(entry[:set])} on Phish.net"
      end
    end
    remaining.each do |track|
      lines << "Not on Phish.net: #{track[:title]} (#{set_label(track[:set])})"
    end
    lines
  end

  def covers?(local_title, pnet_title)
    a = normalize(local_title)
    b = normalize(pnet_title)
    a == b || a.include?(b)
  end

  def normalize(title)
    title.to_s.downcase.gsub(/[^a-z0-9 >]/, "").squish
  end

  def set_label(set)
    SET_NAMES[set.to_s] || set.to_s.presence || "no set"
  end
end
