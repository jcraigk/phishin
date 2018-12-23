# frozen_string_literal: true
namespace :tours do
  desc 'Set starts_on and ends_on based on available shows'
  task range_from_shows: :environment do
    Tour.find_each do |t|
      shows = Show.where(tour_id: t.id).order(date: :asc)
      starts_on, ends_on = (shows.any? ? [shows.first.date, shows.last.date] : [nil, nil])
      t.update_attributes(starts_on: starts_on, ends_on: ends_on)
      puts "#{t.name}: #{t.starts_on} - #{t.ends_on}"
    end
  end
end
