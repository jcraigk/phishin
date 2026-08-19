namespace :guest_tags do
  desc "Report Guest tags that describe only band members (DRY_RUN=false to delete)"
  task audit: :environment do
    dry_run = ENV["DRY_RUN"] != "false"

    report = GuestTagAuditService.call(dry_run:)

    puts "Guest tags scanned: #{report[:scanned]}"
    puts "\nNaming no guest (#{report[:flagged].size}):"
    report[:flagged].each do |entry|
      puts "  #{entry[:date]} #{entry[:title]}"
      puts "      #{entry[:notes]}"
    end

    if dry_run
      puts "\nDry run. Re-run with DRY_RUN=false to apply."
    else
      puts "\nDeleted #{report[:deleted]} tag(s)."
    end
  end
end
