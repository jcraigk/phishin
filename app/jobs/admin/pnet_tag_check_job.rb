class Admin::PnetTagCheckJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      admin_job.update!(message: "Checking the Phish.net Tease Chart", progress: 10)
      chart = TeaseChartSyncService.new(
        start_date: show.date.to_s, end_date: show.date.to_s
      )
      chart.call

      admin_job.update!(message: "Analyzing Phish.net setlist notes", progress: 50)
      notes = TeaseSyncService.new(date: show.date.to_s)
      notes.call

      admin_job.payload["report"] = build_report(chart, notes)
      admin_job.save!
    end
  end

  private

  def build_report(chart, notes)
    sections = []
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
end
