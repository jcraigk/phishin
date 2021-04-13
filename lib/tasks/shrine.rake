# frozen_string_literal: true
namespace :shrine do
  desc 'Populate Shrine data from paperclip fields'
  task convert: :environment do
    relation = Track.unscoped.where(audio_file_data: nil).order(id: :asc)
    pbar = ProgressBar.create(total: relation.count, format: '%a %B %c/%C %p%% %E')

    relation.find_each do |track|
      track.write_shrine_data(:audio_file)
      track.save!

      pbar.increment
    end

    pbar.finish
  end
end
