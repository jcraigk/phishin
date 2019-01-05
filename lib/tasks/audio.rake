# frozen_string_literal: true
namespace :audio do
  desc 'Fix tracks with extra audio'
  task fix: :environment do
    Dir.foreach("#{IMPORT_DIR}/fix") do |item|
      next if item == '.' or item == '..'
      parts = item.split(' ')
      date = parts.second
      title = parts[2..-2].join(' ')
      show = Show.find_by(date: date)
      track = Track.find_by(show: show, title: title)
      track.update(audio_file: File.new("#{IMPORT_DIR}/fix/#{item}", 'r'))
      track.save_duration
      show.save_duration
      puts track.mp3_url
    end
  end
end
