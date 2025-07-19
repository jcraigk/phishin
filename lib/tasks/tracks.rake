namespace :tracks do
  desc "Populate song performance gaps"
  task populate_gaps: :environment do
    rel = Show.published.order(date: :asc)
    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      GapService.call(show)
      pbar.increment
    end

    pbar.finish
  end

  desc "Regenerate waveform images (resizing)"
  task generate_images: :environment do
    relation = Track.select(:id)
    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
    )

    relation.find_each do |track|
      RegenerateTrackWaveformJob.perform_async(track.id)
      pbar.increment
    end

    pbar.finish
  end
end
