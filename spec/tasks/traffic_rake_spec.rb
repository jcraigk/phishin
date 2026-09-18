require "rails_helper"
require "rake"

RSpec.describe "traffic:report" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("traffic:report")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/traffic.rake")
  end

  def run_task(days = nil)
    output = StringIO.new
    $stdout = output
    Rake::Task["traffic:report"].execute(days:)
    output.string
  ensure
    $stdout = STDOUT
  end

  it "prints totals by client plus top routes, ips and user agents within the window" do
    TrafficCount.create!(hour: Time.current.beginning_of_hour, client: "api", route: "/years", ip: "203.0.113.5", user_agent: "curl/8.0", count: 7)
    TrafficCount.create!(hour: 2.days.ago.beginning_of_hour, client: "api", route: "/shows/:date", ip: "198.51.100.9", user_agent: "python-requests/2.31", count: 3)
    TrafficCount.create!(hour: Time.current.beginning_of_hour, client: "web", logged_in: true, route: "/shows/:date", count: 40)
    TrafficCount.create!(hour: 60.days.ago.beginning_of_hour, client: "api", route: "/tags", ip: "192.0.2.1", user_agent: "old-bot/1.0", count: 99)

    output = run_task(30)

    expect(output).to include("50 requests", "web 40", "api 10", "logged in 40")
    expect(output).to include("/years", "203.0.113.5", "curl/8.0")
    expect(output).to include("/shows/:date", "198.51.100.9", "python-requests/2.31")
    expect(output).not_to include("old-bot/1.0", "(blank)")
  end
end
