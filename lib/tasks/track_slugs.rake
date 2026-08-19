namespace :track_slugs do
  desc "Abbreviate long-form track slugs to match TrackSlugGenerator (DRY_RUN=false to apply)"
  task abbreviate: :environment do
    dry_run = ENV["DRY_RUN"] != "false"

    updates = TrackSlugAbbreviator.call(dry_run:)

    puts "Tracks with long-form slugs: #{updates.size}"
    updates.group_by { |u| u[:rule] }.sort_by { |_, v| -v.size }.each do |rule, group|
      puts "  #{group.size.to_s.rjust(4)}  #{rule}"
      group.first(3).each { |u| puts "          #{u[:date]} #{u[:from]} -> #{u[:to]}" }
    end

    if dry_run
      puts "\nDry run. Re-run with DRY_RUN=false to apply."
    else
      puts "\nUpdated #{updates.size} slug(s). Clearing cache..."
      Rails.cache.clear
    end
  end
end
