# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_29_014210) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["created_at"], name: "index_announcements_on_created_at"
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "email", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "revoked_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_api_keys_on_email", unique: true
    t.index ["key"], name: "index_api_keys_on_key", unique: true
    t.index ["name"], name: "index_api_keys_on_name", unique: true
  end

  create_table "authentications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["provider", "uid"], name: "index_authentications_on_provider_and_uid"
    t.index ["user_id"], name: "index_authentications_on_user_id"
  end

  create_table "likes", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "likable_id"
    t.string "likable_type", limit: 255
    t.integer "user_id"
    t.index ["likable_id", "likable_type", "user_id"], name: "index_likes_on_likable_and_user_uniq", unique: true
    t.index ["likable_id"], name: "index_likes_on_likable_id"
    t.index ["likable_type"], name: "index_likes_on_likable_type"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "playlist_tracks", id: :serial, force: :cascade do |t|
    t.integer "duration"
    t.integer "ends_at_second"
    t.integer "playlist_id"
    t.integer "position"
    t.integer "starts_at_second"
    t.integer "track_id"
    t.index ["duration"], name: "index_playlist_tracks_on_duration"
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["position", "playlist_id"], name: "index_playlist_tracks_on_position_and_playlist_id", unique: true
    t.index ["position"], name: "index_playlist_tracks_on_position"
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.integer "duration", default: 0
    t.integer "likes_count", default: 0
    t.string "name", limit: 255, null: false
    t.boolean "published", default: false
    t.string "slug", limit: 255, null: false
    t.integer "tracks_count", default: 0
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["duration"], name: "index_playlists_on_duration"
    t.index ["likes_count"], name: "index_playlists_on_likes_count"
    t.index ["name"], name: "index_playlists_on_name", unique: true
    t.index ["slug"], name: "index_playlists_on_slug", unique: true
    t.index ["tracks_count"], name: "index_playlists_on_tracks_count"
    t.index ["updated_at"], name: "index_playlists_on_updated_at"
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "show_tags", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "notes"
    t.integer "show_id"
    t.integer "tag_id"
    t.index ["notes"], name: "index_show_tags_on_notes"
    t.index ["show_id"], name: "index_show_tags_on_show_id"
    t.index ["tag_id", "show_id"], name: "index_show_tags_on_tag_id_and_show_id", unique: true
  end

  create_table "shows", id: :serial, force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "album_zip_requested_at"
    t.string "audio_status", default: "complete", null: false
    t.string "cover_art_hue"
    t.integer "cover_art_parent_show_id"
    t.text "cover_art_prompt"
    t.string "cover_art_style"
    t.datetime "created_at", precision: nil, null: false
    t.date "date", null: false
    t.integer "duration", default: 0, null: false
    t.integer "likes_count", default: 0
    t.boolean "matches_pnet", default: false
    t.integer "performance_gap_value", default: 1
    t.integer "tags_count", default: 0
    t.text "taper_notes"
    t.integer "tour_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "venue_id"
    t.string "venue_name", default: "", null: false
    t.index "EXTRACT(day FROM date)", name: "index_shows_on_day_extracted"
    t.index "EXTRACT(month FROM date)", name: "index_shows_on_month_extracted"
    t.index "EXTRACT(month FROM date), EXTRACT(day FROM date)", name: "index_shows_on_month_day_extracted"
    t.index "date_part('year'::text, date)", name: "index_shows_on_year_extracted"
    t.index ["audio_status", "venue_id"], name: "index_shows_on_audio_venue"
    t.index ["audio_status"], name: "index_shows_on_audio_status"
    t.index ["date", "performance_gap_value", "audio_status"], name: "index_shows_on_date_performance_gap_audio"
    t.index ["date", "performance_gap_value"], name: "index_shows_with_audio_on_date_performance_gap", where: "((audio_status)::text = ANY (ARRAY[('complete'::character varying)::text, ('partial'::character varying)::text]))"
    t.index ["date"], name: "index_shows_on_date", unique: true
    t.index ["duration"], name: "index_shows_on_duration"
    t.index ["likes_count"], name: "index_shows_on_likes_count"
    t.index ["performance_gap_value", "audio_status", "date"], name: "index_shows_on_performance_gap_audio_date"
    t.index ["tour_id"], name: "index_shows_on_tour_id"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "songs", id: :serial, force: :cascade do |t|
    t.string "alias"
    t.string "artist"
    t.datetime "created_at", precision: nil, null: false
    t.text "lyrics"
    t.boolean "original", default: false, null: false
    t.string "slug", limit: 255, null: false
    t.string "title", limit: 255, null: false
    t.integer "tracks_count", default: 0
    t.integer "tracks_with_audio_count", default: 0
    t.datetime "updated_at", precision: nil, null: false
    t.index ["alias"], name: "index_songs_on_alias", unique: true
    t.index ["original"], name: "index_songs_on_original"
    t.index ["slug"], name: "index_songs_on_slug", unique: true
    t.index ["title"], name: "index_songs_on_title", unique: true
    t.index ["tracks_with_audio_count"], name: "index_songs_on_tracks_with_audio_count"
  end

  create_table "songs_tracks", id: :serial, force: :cascade do |t|
    t.integer "next_performance_gap"
    t.integer "next_performance_gap_with_audio"
    t.string "next_performance_slug"
    t.string "next_performance_slug_with_audio"
    t.integer "previous_performance_gap"
    t.integer "previous_performance_gap_with_audio"
    t.string "previous_performance_slug"
    t.string "previous_performance_slug_with_audio"
    t.integer "song_id"
    t.integer "track_id"
    t.index ["next_performance_gap"], name: "index_songs_tracks_on_next_performance_gap"
    t.index ["next_performance_gap_with_audio"], name: "index_songs_tracks_on_next_performance_gap_with_audio"
    t.index ["previous_performance_gap"], name: "index_songs_tracks_on_previous_performance_gap"
    t.index ["previous_performance_gap_with_audio"], name: "index_songs_tracks_on_previous_performance_gap_with_audio"
    t.index ["song_id", "track_id"], name: "index_songs_tracks_on_song_track_optimized"
    t.index ["song_id"], name: "index_songs_tracks_on_song_id"
    t.index ["track_id", "song_id"], name: "index_songs_tracks_on_track_id_and_song_id", unique: true
    t.index ["track_id"], name: "index_songs_tracks_on_track_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "color", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.text "description"
    t.string "group", default: "", null: false
    t.string "name", limit: 255, null: false
    t.integer "priority", default: 0, null: false
    t.integer "shows_count", default: 0
    t.string "slug", null: false
    t.integer "tracks_count", default: 0
    t.datetime "updated_at", precision: nil, null: false
    t.index ["description"], name: "index_tags_on_description"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["priority"], name: "index_tags_on_priority", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "tours", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.date "ends_on", null: false
    t.string "name", limit: 255, null: false
    t.integer "shows_count", default: 0
    t.integer "shows_with_audio_count", default: 0
    t.string "slug", limit: 255, null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["ends_on"], name: "index_tours_on_ends_on", unique: true
    t.index ["name"], name: "index_tours_on_name", unique: true
    t.index ["shows_with_audio_count"], name: "index_tours_on_shows_with_audio_count"
    t.index ["slug"], name: "index_tours_on_slug", unique: true
    t.index ["starts_on"], name: "index_tours_on_starts_on", unique: true
  end

  create_table "track_tags", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "ends_at_second"
    t.text "notes"
    t.integer "starts_at_second"
    t.integer "tag_id"
    t.integer "track_id"
    t.text "transcript"
    t.index ["notes"], name: "index_track_tags_on_notes"
    t.index ["tag_id"], name: "index_track_tags_on_tag_id"
    t.index ["track_id"], name: "index_track_tags_on_track_id"
  end

  create_table "tracks", id: :serial, force: :cascade do |t|
    t.string "audio_status", default: "complete", null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "duration", default: 0, null: false
    t.boolean "exclude_from_stats", default: false
    t.integer "jam_starts_at_second"
    t.integer "likes_count", default: 0
    t.integer "position", null: false
    t.string "set", limit: 255, null: false
    t.integer "show_id"
    t.string "slug", limit: 255, null: false
    t.integer "tags_count", default: 0
    t.string "title", limit: 255, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["audio_status"], name: "index_tracks_on_audio_status"
    t.index ["jam_starts_at_second"], name: "index_tracks_on_jam_starts_at_second"
    t.index ["likes_count"], name: "index_tracks_on_likes_count"
    t.index ["set", "exclude_from_stats", "show_id", "position"], name: "index_tracks_on_set_exclude_show_position"
    t.index ["show_id", "position"], name: "index_tracks_on_show_id_and_position", unique: true
    t.index ["show_id", "set", "exclude_from_stats", "position"], name: "index_tracks_on_show_set_exclude_position"
    t.index ["show_id", "slug"], name: "index_tracks_on_show_id_and_slug", unique: true
    t.index ["slug"], name: "index_tracks_on_slug"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.integer "access_count_to_reset_password_page", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.string "crypted_password"
    t.string "email", limit: 255, default: "", null: false
    t.string "remember_me_token"
    t.datetime "remember_me_token_expires_at"
    t.datetime "reset_password_email_sent_at"
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_token_expires_at"
    t.string "salt"
    t.datetime "updated_at", precision: nil, null: false
    t.string "username", limit: 255, default: "", null: false
    t.datetime "username_updated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["remember_me_token"], name: "index_users_on_remember_me_token"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "venue_renames", force: :cascade do |t|
    t.string "name", null: false
    t.date "renamed_on", null: false
    t.integer "venue_id"
    t.index ["name", "renamed_on"], name: "index_venue_renames_on_name_and_renamed_on", unique: true
    t.index ["venue_id"], name: "index_venue_renames_on_venue_id"
  end

  create_table "venues", id: :serial, force: :cascade do |t|
    t.string "abbrev", limit: 255
    t.string "city", limit: 255, null: false
    t.string "country", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.float "latitude"
    t.float "longitude"
    t.string "name", limit: 255, null: false
    t.integer "shows_count", default: 0
    t.integer "shows_with_audio_count", default: 0
    t.string "slug", limit: 255, null: false
    t.string "state", limit: 255, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name", "city"], name: "index_venues_on_name_and_city", unique: true
    t.index ["shows_with_audio_count"], name: "index_venues_on_shows_with_audio_count"
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
