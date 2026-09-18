namespace :traffic do
  desc "Report web and API traffic over the last N days (default 30)"
  task :report, [ :days ] => :environment do |_t, args|
    days = (args[:days] || 30).to_i
    scope = TrafficCount.where(hour: days.days.ago..)
    by_client = scope.group(:client).sum(:count)
    logged_in = scope.where(logged_in: true).sum(:count)

    puts "Traffic, last #{days} days: #{scope.sum(:count)} requests"
    puts "  web #{by_client['web'] || 0}, api #{by_client['api'] || 0}, logged in #{logged_in}"

    {
      "Routes" => scope.group(:route),
      "IPs" => scope.where.not(ip: "").group(:ip),
      "User agents" => scope.where.not(user_agent: "").group(:user_agent)
    }.each do |title, grouped|
      rows = grouped.sum(:count).sort_by { -_2 }.first(25)
      puts "\n#{title}"
      rows.each { |value, count| puts format("%10d  %s", count, value) }
    end
  end
end
