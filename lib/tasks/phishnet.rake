# frozen_string_literal: true
namespace :phishnet do
  desc 'Sync jamcharts data'
  task jamcharts: :environment do
    puts 'Fetching Jamcharts data from Phish.net API...'
    JamchartsImporter.new(ENV['PHISHNET_API_KEY']).call
  end
end
