namespace :sets do
  desc "Find duplicate sets (identical order and same songs regardless of order)"
  task duplicates: :environment do
    puts "Analyzing sets for duplicates...\n\n"

    set_data = Track
      .where(set: %w[1 2 3])
      .joins(:songs_tracks)
      .joins(:show)
      .group("tracks.show_id", "tracks.set", "shows.date")
      .pluck(
        Arel.sql("tracks.show_id"),
        Arel.sql("tracks.set"),
        Arel.sql("STRING_AGG(songs_tracks.song_id::text, ',' ORDER BY tracks.position)"),
        Arel.sql("STRING_AGG(songs_tracks.song_id::text, ',' ORDER BY songs_tracks.song_id)"),
        Arel.sql("shows.date")
      )

    sets_by_ordered = Hash.new { |h, k| h[k] = [] }
    sets_by_unordered = Hash.new { |h, k| h[k] = [] }

    set_data.each do |show_id, set, ordered_sig, unordered_sig, date|
      key = [set, ordered_sig]
      sets_by_ordered[key] << { show_id:, date:, set: }

      key_unordered = [set, unordered_sig]
      sets_by_unordered[key_unordered] << { show_id:, date:, set:, ordered_sig: }
    end

    identical_duplicates = sets_by_ordered.select { |_, v| v.size > 1 }
    same_songs_duplicates = sets_by_unordered.select { |_, v| v.size > 1 }

    same_songs_only = same_songs_duplicates.reject do |key, entries|
      ordered_sigs = entries.map { |e| e[:ordered_sig] }.uniq
      ordered_sigs.size == 1
    end

    puts "=" * 60
    puts "IDENTICAL SETS (same songs, same order)"
    puts "=" * 60

    if identical_duplicates.empty?
      puts "No identical sets found.\n\n"
    else
      identical_duplicates.sort_by { |_, v| -v.size }.each do |(set, _), entries|
        songs = Track
          .joins(:songs)
          .where(show_id: entries.first[:show_id], set:)
          .order(:position)
          .pluck("songs.title")

        puts "\nSet #{set} - #{entries.size} occurrences:"
        puts "Songs: #{songs.join(' > ')}"
        puts "Dates: #{entries.map { |e| e[:date] }.sort.join(', ')}"
      end
      puts
    end

    puts "=" * 60
    puts "SAME SONGS, DIFFERENT ORDER"
    puts "=" * 60

    if same_songs_only.empty?
      puts "No sets with same songs in different order found.\n\n"
    else
      same_songs_only.sort_by { |_, v| -v.size }.each do |(set, _), entries|
        song_ids = entries.first[:ordered_sig].split(",").map(&:to_i)
        song_titles = Song.where(id: song_ids).pluck(:id, :title).to_h

        puts "\nSet #{set} - #{entries.size} occurrences:"
        puts "Songs: #{song_ids.map { |id| song_titles[id] }.join(', ')}"

        entries.sort_by { |e| e[:date] }.each do |entry|
          ordered_ids = entry[:ordered_sig].split(",").map(&:to_i)
          puts "  #{entry[:date]}: #{ordered_ids.map { |id| song_titles[id] }.join(' > ')}"
        end
      end
      puts
    end

    puts "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Identical sets: #{identical_duplicates.size}"
    puts "Same songs, different order: #{same_songs_only.size}"
  end
end

