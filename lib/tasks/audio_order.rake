# Verify and fix track ordering within a show using audio junction continuity
# (see scripts/audio_junction_analysis.py). Two-step workflow:
#
#   bin/rails "tracks:audio_order[1991-03-17]"
#     Analyze the show: score junctions, search placements for floaters, write
#     data/audio_order/<date>/ with proposed.json, review.html, splice clips.
#     FLOATERS=slug-or-id,slug-or-id names tracks whose position is unknown.
#     PINS=id-or-slug:rank,... locks floaters to reviewed candidates (CLI
#     alternative to the review-page radio buttons).
#
#   bin/rails "tracks:audio_order[/content/import/1991-03-17.json]"
#     Renumber the show's tracks after human review. Passing a JSON path
#     implies apply, and the show date is read from the file. The input is
#     the file exported from review.html's radio buttons (named <date>.json,
#     self-contained: date + current order + slot choices); with selections
#     there is no ambiguity gate - the choices are the review.
#
#     APPLY=true (no path) applies from the default data/audio_order/<date>/
#     location. Without a selections file, apply falls back to proposed.json
#     (third arg or PROPOSAL= to relocate it) and refuses ambiguous floaters
#     unless ACCEPT_AMBIGUOUS=true accepts their best-guess slots.
#
#     Either way it refuses if the show's track IDs changed since analysis.
namespace :tracks do
  desc "Analyze (or APPLY=true fix) a show's track order via audio junction continuity"
  task :audio_order, [ :date, :selections, :proposal ] => :environment do |_t, task_args|
    arg = task_args[:date] || abort("Usage: bin/rails \"tracks:audio_order[YYYY-MM-DD]\" " \
                                    "or bin/rails \"tracks:audio_order[/path/to/YYYY-MM-DD.json]\"")

    # A .json first argument is a review export; the date comes from the file.
    if arg.end_with?(".json")
      selections_arg = Pathname.new(arg)
      abort "No such file: #{selections_arg}" unless selections_arg.exist?
      date = JSON.parse(selections_arg.read)["date"] ||
             abort("#{selections_arg} has no date field - re-export from review.html")
    else
      date = arg
      selections_arg = (task_args[:selections] || ENV["SELECTIONS"]).presence&.then { |p| Pathname.new(p) }
    end
    out_dir = Rails.root.join("data/audio_order", date)

    # Passing a JSON file (arg or env) means "apply it"; APPLY=true covers
    # applying from the default data/audio_order/<date>/ location.
    apply = ENV["APPLY"] == "true" || selections_arg.present? ||
            [ task_args[:proposal], ENV["PROPOSAL"] ].any?(&:present?)

    if apply
      selections_path = selections_arg || out_dir.join("#{date}.json")

      if selections_path.exist?
        # Human-reviewed slot choices exported from review.html; no ambiguity gate.
        data = JSON.parse(selections_path.read)
        unless data.is_a?(Hash) && data["date"] && data["current_order"] && data["selections"]
          abort "#{selections_path} is not a review export (expected date/current_order/selections)"
        end
        abort "Selections are for #{data['date']}, not #{date}" unless data["date"] == date

        selections = data["selections"]
        ids = data["current_order"] - selections.map { |s| s.fetch("id") }
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
        report_path = (task_args[:proposal] || ENV["PROPOSAL"]).presence&.then { |p| Pathname.new(p) } ||
                      out_dir.join("proposed.json")
        unless report_path.exist?
          abort "No selections at #{selections_path} and no proposal at #{report_path} - " \
                "run analysis first or pass a file path"
        end
        report = JSON.parse(report_path.read)
        abort "Proposal is for #{report['date']}, not #{date}" unless report["date"] == date

        accept_ambiguous = ENV["ACCEPT_AMBIGUOUS"] == "true"
        ambiguous = report["ambiguous_floaters"]
        if ambiguous.any? && !accept_ambiguous
          titles = Track.where(id: ambiguous).pluck(:title).join(", ")
          abort "Proposal has ambiguous floaters (#{titles}) - review " \
                "#{out_dir.join('review.html')}, export #{date}.json, " \
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
