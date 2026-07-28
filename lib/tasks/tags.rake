namespace :tags do
  desc "Reapply notes normalization to existing show and track tags"
  task normalize_notes: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    [ ShowTag, TrackTag ].each do |model|
      updated = 0
      model.where.not(notes: nil).find_each do |record|
        normalized = model.normalize_value_for(:notes, record.notes)
        next if normalized == record.notes
        puts "#{model.name} ##{record.id}: #{record.notes.inspect} becomes #{normalized.inspect}" if dry_run
        record.update!(notes: normalized) unless dry_run
        updated += 1
      end
      puts "#{model.name}: #{updated} record(s)#{dry_run ? ' would be' : ''} updated"
    end
  end
end
