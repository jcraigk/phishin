# Builds and rolls back a repeatable local fixture for exercising the admin UI
# against real audio. See lib/tasks/admin_fixture.rake for the entry points.
#
# The development database ships with attachment RECORDS but no attachment
# FILES, which is why PRODUCTION_CONTENT=true works: every blob URL redirects
# to phish.in. That is fine for browsing and useless for testing the admin
# audio tools, which read bytes off the local disk and write new ones back.
#
# Production serves blobs by key at /blob/<key>.<ext> and the local database
# already holds those keys, so the download needs no API calls and no metadata
# changes: the same key that resolves remotely resolves locally once the file
# is on disk.
class AdminFixture
  # Three shows, deliberately different, so a restore has something real to
  # prove it put back and the timestamp rules have something real to move:
  #
  #   1992-07-11  10 tracks, one timestamped tag. The small, fast case.
  #   1990-12-28  24 tracks, likes, tags and playlist entries.
  #   1993-04-13  21 tracks and six timestamped tags, three of them on a single
  #               20 minute "Mike's Song > I Am Hydrogen > Weekapaug Groove" at
  #               211s, 298s and 459s. A segue track long enough to split, with
  #               several tags on one clock, is the case where a shift that gets
  #               its delta wrong moves some tags and not others.
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

    # --- snapshot ------------------------------------------------------------

    # Attributes are read from the schema rather than listed, because this
    # database is not always on the same migration as the branch being tested -
    # the admin-ui branch adds shows.published, and a hardcoded list would either
    # miss it or blow up on a database that predates it.
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

    # Blob KEYS are what matter here. An audio tool replaces a track's attachment
    # with a new blob, so restoring the row is not enough - the attachment has to
    # point back at the original key or the show still plays the edited audio.
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

    # --- download ------------------------------------------------------------

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

    # Written to a temp file and moved into place, so an interrupted download
    # cannot leave a truncated file that service.exist? then reports as present.
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

    # --- restore -------------------------------------------------------------

    # Order matters: tracks are deleted and rebuilt from the snapshot because an
    # audio tool may have split one into two or combined two into one, so the
    # rows present now are not necessarily the rows the snapshot describes.
    # Everything that references a track is restored after the tracks exist.
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

    # Only columns the current schema actually has, so a snapshot taken on one
    # migration still restores on another.
    def restorable(klass, attrs)
      attrs.slice(*klass.column_names).except("id")
  end

    # Points each attachment back at its ORIGINAL blob, recreating the blob row
    # when an edit replaced it. The downloaded file is still on disk under the
    # original key, so a restored show plays the original audio again.
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

    # Counter caches are written back from the snapshot rather than recounted.
    # A show's likes_count covers likes this fixture does not own - the snapshot
    # only carries likes belonging to this show and its tracks - so recounting
    # would zero a number that was never wrong. The tracks are recounted from
    # their restored likes because their rows were just rebuilt.
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

    # insert_all skips validations and callbacks on purpose: these rows are being
    # put back exactly as they were, not created afresh.
    def insert_rows(klass, rows)
      return if rows.blank?
      klass.insert_all(rows.map { it.slice(*klass.column_names) })
  end

    # --- helpers -------------------------------------------------------------

    # Compared through JSON on both sides, because a snapshot round trip turns a
    # Date into a String and a TimeWithZone into a formatted String. The two
    # sides still format timestamps differently ("... -0400" versus ISO8601), and
    # updated_at moves on any touch regardless, so timestamps are dropped: this
    # is a report on what an admin changed, not on when a row was written.
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
