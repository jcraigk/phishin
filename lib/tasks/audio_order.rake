# Verify and fix track ordering within a show using audio junction continuity
# (see scripts/audio_junction_analysis.py). Two-step workflow:
#
#   bin/rails "tracks:audio_order[1991-03-17]"
#     Analyze the show: score junctions, search placements for floaters, write
#     data/audio_order/<date>/ with proposed.json, review.html, splice clips.
#     FLOATERS=slug-or-id,slug-or-id names tracks whose position is unknown.
#
#   APPLY=true bin/rails "tracks:audio_order[1991-03-17]"
#     Renumber the show's tracks to the proposed order after human review.
#     Refuses if the proposal is missing, has ambiguous floaters, or the
#     show's track IDs have changed since analysis.
#
#     Preferred review flow: pick slots via the radio buttons in review.html,
#     Export, save as data/audio_order/<date>/selections.json (or point at it
#     with SELECTIONS=path) - APPLY then uses exactly those choices and skips
#     the ambiguity gate. Without selections, ACCEPT_AMBIGUOUS=true applies
#     ambiguous floaters at their best-guess slots instead.
namespace :tracks do
  desc "Analyze (or APPLY=true fix) a show's track order via audio junction continuity"
  task :audio_order, [ :date ] => :environment do |_t, task_args|
    date = task_args[:date] || abort("Usage: bin/rails \"tracks:audio_order[YYYY-MM-DD]\"")
    out_dir = Rails.root.join("data/audio_order", date)

    if ENV["APPLY"] == "true"
      report_path = out_dir.join("proposed.json")
      abort "No proposal at #{report_path} - run analysis first" unless report_path.exist?
      report = JSON.parse(report_path.read)
      abort "Proposal is for #{report['date']}, not #{date}" unless report["date"] == date

      selections_path = ENV["SELECTIONS"].presence&.then { |p| Pathname.new(p) } ||
                        out_dir.join("selections.json")
      if selections_path.exist?
        # Human-reviewed slot choices exported from review.html; no ambiguity gate.
        selections = JSON.parse(selections_path.read)
        ids = report.fetch("current_order") - selections.map { |s| s.fetch("id") }
        last_in_slot = {}
        selections.each do |s|
          anchor = last_in_slot[[ s["after_id"], s["before_id"] ]] || s["after_id"]
          idx =
            if anchor
              i = ids.index(anchor) or abort("Selection anchor #{anchor} not found for #{s['title']}")
              i + 1
            elsif s["before_id"]
              ids.index(s["before_id"]) or abort("Selection anchor #{s['before_id']} not found for #{s['title']}")
            else
              ids.length
            end
          ids.insert(idx, s.fetch("id"))
          last_in_slot[[ s["after_id"], s["before_id"] ]] = s["id"]
        end
        puts "Using #{selections.size} reviewed selection(s) from #{selections_path}"
      else
        accept_ambiguous = ENV["ACCEPT_AMBIGUOUS"] == "true"
        ambiguous = report["ambiguous_floaters"]
        if ambiguous.any? && !accept_ambiguous
          titles = Track.where(id: ambiguous).pluck(:title).join(", ")
          abort "Proposal has ambiguous floaters (#{titles}) - review " \
                "#{out_dir.join('review.html')}, export selections.json, " \
                "or re-run with ACCEPT_AMBIGUOUS=true for best-guess slots"
        end
        ids = accept_ambiguous ? report.fetch("proposed_order_full") : report["proposed_order"]
      end
      show = Show.find_by!(date:)
      current = show.tracks.order(:position).pluck(:id)
      if current.sort != ids.sort
        abort "Track IDs changed since analysis " \
              "(missing: #{(ids - current).inspect}, unexpected: #{(current - ids).inspect})"
      end
      if current == ids
        puts "Already in proposed order; nothing to do"
        next
      end

      Track.transaction do
        tracks = show.tracks.index_by(&:id)
        ids.each_with_index { |id, i| tracks[id].update_column(:position, 1000 + i) }
        ids.each_with_index { |id, i| tracks[id].update!(position: i + 1) }
      end
      puts "Applied proposed order to #{date}"
      show.reload.tracks.order(:position).each do |t|
        puts format("  %2d %-3s %s", t.position, t.set, t.title)
      end
    else
      abort "uv not found. Install it first: https://docs.astral.sh/uv/" unless system("which uv > /dev/null 2>&1")
      cmd = [ "uv", "run", "scripts/audio_junction_analysis.py", "--show", date ]
      cmd += [ "--floaters", ENV["FLOATERS"] ] if ENV["FLOATERS"].present?
      cmd += [ "--pins", ENV["PINS"] ] if ENV["PINS"].present?
      puts "Running: #{cmd.join(' ')}"
      system(*cmd) || abort("Analysis failed")
    end
  end
end
