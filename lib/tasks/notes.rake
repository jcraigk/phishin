namespace :notes do
  desc "Decode HTML entities in notes and transcript fields (DRY_RUN=true to preview)"
  task fix_html_entities: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    targets = {
      ShowTag => %i[notes],
      TrackTag => %i[notes transcript],
      Show => %i[taper_notes admin_notes]
    }

    targets.each do |model, columns|
      columns.each do |column|
        updated = 0
        model.where("#{column} LIKE '%&%'").find_each do |record|
          original = record[column]
          decoded = NormalizesNotes.decode_html_entities(original)
          next if decoded == original
          puts "#{model.name} ##{record.id} #{column}: #{original.inspect} becomes #{decoded.inspect}"
          record.update!(column => decoded) unless dry_run
          updated += 1
        end
        puts "#{model.name}.#{column}: #{updated} record(s)#{dry_run ? ' would be' : ''} updated"
      end
    end
  end
end
