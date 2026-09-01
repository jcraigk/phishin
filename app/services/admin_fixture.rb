class AdminFixture
  DATES = %w[1992-07-11 1990-12-28 1993-04-13].freeze
  SNAPSHOT_DIR = Rails.root.join("tmp/admin_fixture")

  class << self
    def setup
      guard!
      FileUtils.mkdir_p(SNAPSHOT_DIR)
      DATES.each do |date|
        show = find!(date)
        snapshot(show)
        puts "#{date}: snapshot written"
        download_blobs(show)
      end
      puts
      puts "Set PRODUCTION_CONTENT=false in .env and restart the app to serve these locally."
    end

    def status
      DATES.each do |date|
        show = Show.find_by(date:)
        next puts "#{date}: not in this database" if show.nil?

        files = blobs_for(show)
        on_disk = files.count { service.exist?(it.key) }
        path = snapshot_path(date)
        drift = File.exist?(path) ? drifted_fields(show, JSON.parse(File.read(path))) : nil

        puts "#{date}: #{on_disk}/#{files.size} blob files on disk"
        puts "  snapshot: #{File.exist?(path) ? path.to_s : 'NONE - run admin_fixture:setup'}"
        puts "  drift: #{drift.nil? ? 'unknown' : (drift.empty? ? 'none' : drift.join(', '))}"
      end
    end

    def restore_all
      guard!
      DATES.each do |date|
        path = snapshot_path(date)
        next puts "#{date}: no snapshot, skipping" unless File.exist?(path)
        restore(JSON.parse(File.read(path)))
        puts "#{date}: restored"
      end
      puts
      puts "Downloaded blob files were left in place so a later setup is instant."
    end

    private

    def guard!
      raise "Refusing to run outside development." unless Rails.env.development?
    end

    def find!(date)
      Show.find_by(date:) || raise("#{date} is not in this database.")
    end

    def snapshot(show)
      data = {
      "date" => show.date.to_s,
      "show" => show.attributes,
      "song_ids" => show.tracks.to_h { |t| [ t.id.to_s, t.song_ids ] },
      "tracks" => show.tracks.order(:position).map(&:attributes),
      "attachments" => attachment_rows(show),
      "show_tags" => show.show_tags.map(&:attributes),
      "track_tags" => TrackTag.where(track: show.tracks).map(&:attributes),
      "likes" => Like.where(likable: show.tracks).or(Like.where(likable: show))
                     .map(&:attributes),
      "playlist_tracks" => PlaylistTrack.where(track: show.tracks).map(&:attributes)
      }
      File.write(snapshot_path(show.date.to_s), JSON.pretty_generate(data))
  end

    def attachment_rows(show)
      ActiveStorage::Attachment
      .where(record: [ show ] + show.tracks.to_a)
      .includes(:blob)
      .map do |att|
        {
          "record_type" => att.record_type,
          "record_id" => att.record_id,
          "name" => att.name,
          "blob_key" => att.blob.key,
          "filename" => att.blob.read_attribute(:filename),
          "content_type" => att.blob.content_type,
          "byte_size" => att.blob.byte_size,
          "checksum" => att.blob.checksum
        }
      end
  end

    def download_blobs(show)
      blobs = blobs_for(show)
      have = blobs.count { |blob| service.exist?(blob.key) }
      puts "  #{blobs.size} blobs, #{have} already on disk"

      blobs.each_with_index do |blob, i|
      next if service.exist?(blob.key)
      fetch_blob(blob, "  [#{i + 1}/#{blobs.size}]")
      end
  end

    def blobs_for(show)
      ActiveStorage::Attachment
      .where(record: [ show ] + show.tracks.to_a)
      .includes(:blob)
      .map(&:blob)
      .uniq(&:key)
  end

    def fetch_blob(blob, label)
      ext = File.extname(blob.read_attribute(:filename).to_s)
      url = "#{Rails.configuration.production_base_url}/blob/#{blob.key}#{ext}"
      tmp = SNAPSHOT_DIR.join("download-#{blob.key}")

      print "#{label} #{blob.key}#{ext} (#{number_to_human_size(blob.byte_size)}) "
      ok = system("curl", "-sfL", "--max-time", "600", "-o", tmp.to_s, url)
      return puts "FAILED" unless ok && File.exist?(tmp)

      File.open(tmp, "rb") { |file| service.upload(blob.key, file) }
      File.delete(tmp)
      puts "ok"
  end

    def number_to_human_size(bytes)
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end

    def restore(data)
      show = Show.find_by(date: data["date"])
      abort "#{data['date']} vanished from the database." if show.nil?

      ActiveRecord::Base.transaction do
      show.update_columns(restorable(Show, data["show"]))
      restore_tracks(show, data)
      restore_attachments(data)
      restore_associations(show, data)
      end
  end

    def restore_tracks(show, data)
      Track.where(show:).destroy_all
      data["tracks"].each do |attrs|
      track = Track.new
      track.assign_attributes(restorable(Track, attrs))
      track.id = attrs["id"]
      track.save!(validate: false)
      song_ids = data.dig("song_ids", attrs["id"].to_s) || []
      track.song_ids = song_ids if song_ids.any?
      end
  end

    def restorable(klass, attrs)
      attrs.slice(*klass.column_names).except("id")
  end

    def restore_attachments(data)
      data["attachments"].each do |row|
      blob = ActiveStorage::Blob.find_by(key: row["blob_key"]) || ActiveStorage::Blob.create!(
        key: row["blob_key"],
        filename: row["filename"],
        content_type: row["content_type"],
        byte_size: row["byte_size"],
        checksum: row["checksum"],
        service_name:
      )

      ActiveStorage::Attachment
        .where(record_type: row["record_type"], record_id: row["record_id"], name: row["name"])
        .where.not(blob_id: blob.id)
        .destroy_all

      next if ActiveStorage::Attachment.exists?(
        record_type: row["record_type"], record_id: row["record_id"],
        name: row["name"], blob_id: blob.id
      )

      ActiveStorage::Attachment.create!(
        record_type: row["record_type"], record_id: row["record_id"],
        name: row["name"], blob:
      )
      end
  end

    def restore_associations(show, data)
      tracks = Track.where(show:)
      ShowTag.where(show:).destroy_all
      TrackTag.where(track: tracks).destroy_all
      Like.where(likable: tracks).or(Like.where(likable: show)).destroy_all
      PlaylistTrack.where(track: tracks).destroy_all

      insert_rows(ShowTag, data["show_tags"])
      insert_rows(TrackTag, data["track_tags"])
      insert_rows(Like, data["likes"])
      insert_rows(PlaylistTrack, data["playlist_tracks"])

      restore_counters(show.reload, data)
  end

    def restore_counters(show, data)
      show.update_columns(
      restorable(Show, data["show"]).slice("likes_count", "tags_count")
      )
      by_id = data["tracks"].index_by { it["id"] }
      show.tracks.each do |track|
      counts = (by_id[track.id] || {}).slice("likes_count", "tags_count")
      track.update_columns(counts) if counts.any?
      end
  end

    def insert_rows(klass, rows)
      return if rows.blank?
      klass.insert_all(rows.map { it.slice(*klass.column_names) })
  end

    def comparable(klass, attrs)
      JSON.parse(restorable(klass, attrs).except("created_at", "updated_at").to_json)
  end

    def drifted_fields(show, data)
      drift = []
      drift << "show attributes" if comparable(Show, data["show"]) != comparable(Show, show.attributes)
      drift << "track count #{show.tracks.count} vs #{data['tracks'].size}" \
      if show.tracks.count != data["tracks"].size

      keys_now = ActiveStorage::Attachment.where(record: [ show ] + show.tracks.to_a)
                                        .includes(:blob).map { it.blob.key }.sort
      drift << "attachments" if keys_now != data["attachments"].map { it["blob_key"] }.sort
      drift
  end

    def snapshot_path(date) = SNAPSHOT_DIR.join("#{date}.json")

    def service = ActiveStorage::Blob.service

    def service_name = Rails.configuration.active_storage.service
  end
end
