require "rails_helper"

describe "Homepage", :js do
  let(:venue) { create(:venue) }
  let(:most_recent_year) { ERAS.values.flatten.last }
  let!(:shows) do
    [ 1983, most_recent_year ].each_with_object([]) do |year, shows|
      (1..3).each do |day|
        shows << create(:show, venue:, date: "#{year}-01-#{day}", duration: 100_000)
      end
    end
  end

  before do
    shows.last.update(venue: create(:venue))
  end

  it "visit root path" do
    visit "/"

    # Nav
    within("#navbar") do
      expect(page).to have_css('input.search-term[placeholder="SEARCH"]')
      expect(page).to have_link("LOGIN", href: "/login")

      find("button", text: "INFO").click
      expect(page).to have_link("FAQ", href: "/faq")
      expect(page).to have_link("API Docs", href: "/api-docs")
      expect(page).to have_link("Tagin' Project", href: "/tagin-project")
      expect(page).to have_link("Contact Info", href: "/contact-info")
      expect(page).to have_link("Privacy Policy", href: "/privacy")
      expect(page).to have_link("Terms of Service", href: "/terms")

      find("button", text: "CONTENT").click
      expect(page).to have_link("Years", href: "/")
      expect(page).to have_link("Venues", href: "/venues")
      expect(page).to have_link("Songs", href: "/songs")
      expect(page).to have_link("Tags", href: "/tags")
      expect(page).to have_link("Today", href: "/today")
      expect(page).to have_link("Map", href: "/map")
      expect(page).to have_link("Playlists", href: "/playlists")
      expect(page).to have_link("Top 46 Shows", href: "/top-shows")
      expect(page).to have_link("Top 46 Tracks", href: "/top-tracks")

      find("#nav-search").click # Close the dropdown
    end

    within("#sidebar") do
      expect(page).to have_content("#{shows.count} shows")
      total_hours = (shows.sum(&:duration) / (1000 * 60 * 60)).round
      expect(page).to have_content("#{total_hours} hours of music")
      expect(page).to have_selector(".mobile-apps")
      expect(page).to have_link("GitHub")
      expect(page).to have_link("Discord")
      expect(page).to have_link("RSS", href: "/feeds/rss")
    end

    within("#main-content") do
      # Handle the grouped years (1983-1987)
      grouped_years = (1983..1987)
      shows_in_group = shows.select { |show| grouped_years.include?(show.date.year) }
      expect(page).to have_content("1983-1987")
      expect(page).to have_content("#{shows_in_group.count} shows")
      expect(page).to have_link("1983-1987", href: "/1983-1987")

      # Handle the rest of the individual years
      shows.group_by { |show| show.date.year }.each do |year, shows_in_year|
        next if grouped_years.include?(year)  # Skip the grouped years

        expect(page).to have_content(year.to_s)
        expect(page).to have_content("#{shows_in_year.count} shows")
        expect(page).to have_link(year.to_s, href: "/#{year}")
      end
    end

    # Click most recent year
    click_on(most_recent_year)
    sleep 1
    expect(page).to have_current_path("/#{most_recent_year}")
    within("#sidebar") do
      expect(page).to have_content(most_recent_year)
      expect(page).to have_content("3 shows")
    end
    within("#main-content") do
      items = page.all(".grid-item")
      expect(items.size).to eq(3)
    end
  end
end
