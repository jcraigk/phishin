# frozen_string_literal: true
require 'nokogiri'
require 'open-uri'

namespace :tours do
  desc 'Update shows_count cache'
  task sync_shows_count: :environment do
    Tour.order('starts_on').all.each do |t|
      shows = t.shows
      puts "#{t.name} :: #{shows.length}"
      t.update_attributes(shows_count: shows.length)
    end
  end

  desc 'Set starts_on and ends_on based on available shows'
  task calculate_start_and_end: :environment do
    Tour.all.each do |t|
      shows = Show.where(tour_id: t.id).order('date asc').all
      starts_on, ends_on = (shows.present? ? [shows.first.date, shows.last.date] : [nil, nil])
      t.update_attributes(starts_on: starts_on, ends_on: ends_on)
      puts "#{t.name}: #{t.starts_on} - #{t.ends_on}"
    end
  end
end
