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

ActiveRecord::Schema[7.2].define(version: 2024_09_18_023447) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "announcements", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_announcements_on_created_at"
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "key", null: false
    t.datetime "revoked_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_api_keys_on_email", unique: true
    t.index ["key"], name: "index_api_keys_on_key", unique: true
    t.index ["name"], name: "index_api_keys_on_name", unique: true
  end

  create_table "authentications", force: :cascade do |t|
    t.bigint "user_id"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_authentications_on_provider_and_uid"
    t.index ["user_id"], name: "index_authentications_on_user_id"
  end

  create_table "known_dates", force: :cascade do |t|
    t.date "date", null: false
    t.string "phishnet_url"
    t.string "location"
    t.string "venue"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["date"], name: "index_known_dates_on_date", unique: true
  end

  create_table "likes", id: :serial, force: :cascade do |t|
    t.string "likable_type", limit: 255
    t.integer "likable_id"
    t.integer "user_id"
    t.datetime "created_at", precision: nil
    t.index ["likable_id", "likable_type", "user_id"], name: "index_likes_on_likable_and_user_uniq", unique: true
    t.index ["likable_id"], name: "index_likes_on_likable_id"
    t.index ["likable_type"], name: "index_likes_on_likable_type"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "playlist_bookmarks", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "playlist_id"
    t.index ["playlist_id"], name: "index_playlist_bookmarks_on_playlist_id"
    t.index ["user_id"], name: "index_playlist_bookmarks_on_user_id"
  end

  create_table "playlist_tracks", id: :serial, force: :cascade do |t|
    t.integer "playlist_id"
    t.integer "track_id"
    t.integer "position"
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["position", "playlist_id"], name: "index_playlist_tracks_on_position_and_playlist_id", unique: true
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "name", limit: 255, null: false
    t.string "slug", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "duration", default: 0
    t.index ["duration"], name: "index_playlists_on_duration"
    t.index ["name"], name: "index_playlists_on_name", unique: true
    t.index ["slug"], name: "index_playlists_on_slug", unique: true
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "show_tags", id: :serial, force: :cascade do |t|
    t.integer "show_id"
    t.integer "tag_id"
    t.datetime "created_at", precision: nil
    t.text "notes"
    t.index ["notes"], name: "index_show_tags_on_notes"
    t.index ["show_id"], name: "index_show_tags_on_show_id"
    t.index ["tag_id", "show_id"], name: "index_show_tags_on_tag_id_and_show_id", unique: true
  end

  create_table "shows", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "venue_id"
    t.integer "tour_id"
    t.integer "likes_count", default: 0
    t.boolean "incomplete", default: false
    t.text "admin_notes"
    t.integer "duration", default: 0, null: false
    t.text "taper_notes"
    t.integer "tags_count", default: 0
    t.boolean "published", default: false, null: false
    t.string "venue_name", default: "", null: false
    t.boolean "matches_pnet", default: false
    t.index ["date"], name: "index_shows_on_date", unique: true
    t.index ["duration"], name: "index_shows_on_duration"
    t.index ["likes_count"], name: "index_shows_on_likes_count"
    t.index ["tour_id"], name: "index_shows_on_tour_id"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "songs", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "slug", limit: 255, null: false
    t.integer "tracks_count", default: 0
    t.string "lyrical_excerpt", limit: 255
    t.boolean "original", default: false, null: false
    t.string "alias"
    t.text "lyrics"
    t.string "artist"
    t.boolean "instrumental", default: false, null: false
    t.index ["alias"], name: "index_songs_on_alias", unique: true
    t.index ["original"], name: "index_songs_on_original"
    t.index ["slug"], name: "index_songs_on_slug", unique: true
    t.index ["title"], name: "index_songs_on_title", unique: true
  end

  create_table "songs_tracks", id: :serial, force: :cascade do |t|
    t.integer "song_id"
    t.integer "track_id"
    t.integer "previous_performance_gap"
    t.string "previous_performance_slug"
    t.integer "next_performance_gap"
    t.string "next_performance_slug"
    t.index ["next_performance_gap"], name: "index_songs_tracks_on_next_performance_gap"
    t.index ["previous_performance_gap"], name: "index_songs_tracks_on_previous_performance_gap"
    t.index ["song_id"], name: "index_songs_tracks_on_song_id"
    t.index ["track_id", "song_id"], name: "index_songs_tracks_on_track_id_and_song_id", unique: true
    t.index ["track_id"], name: "index_songs_tracks_on_track_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "color", limit: 255, null: false
    t.text "description"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "shows_count", default: 0
    t.integer "tracks_count", default: 0
    t.integer "priority", default: 0, null: false
    t.string "slug", null: false
    t.string "group", default: "", null: false
    t.index ["description"], name: "index_tags_on_description"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["priority"], name: "index_tags_on_priority", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "tours", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.string "slug", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "shows_count", default: 0
    t.index ["ends_on"], name: "index_tours_on_ends_on", unique: true
    t.index ["name"], name: "index_tours_on_name", unique: true
    t.index ["slug"], name: "index_tours_on_slug", unique: true
    t.index ["starts_on"], name: "index_tours_on_starts_on", unique: true
  end

  create_table "track_tags", id: :serial, force: :cascade do |t|
    t.integer "track_id"
    t.integer "tag_id"
    t.datetime "created_at", precision: nil
    t.text "notes"
    t.integer "starts_at_second"
    t.integer "ends_at_second"
    t.text "transcript"
    t.index ["notes"], name: "index_track_tags_on_notes"
    t.index ["tag_id"], name: "index_track_tags_on_tag_id"
    t.index ["track_id"], name: "index_track_tags_on_track_id"
  end

  create_table "tracks", id: :serial, force: :cascade do |t|
    t.integer "show_id"
    t.string "title", limit: 255, null: false
    t.integer "position", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "duration", default: 0, null: false
    t.string "set", limit: 255, null: false
    t.integer "likes_count", default: 0
    t.string "slug", limit: 255, null: false
    t.integer "tags_count", default: 0
    t.integer "jam_starts_at_second"
    t.text "audio_file_data"
    t.float "waveform_max"
    t.text "waveform_png_data"
    t.index ["jam_starts_at_second"], name: "index_tracks_on_jam_starts_at_second"
    t.index ["likes_count"], name: "index_tracks_on_likes_count"
    t.index ["show_id", "position"], name: "index_tracks_on_show_id_and_position", unique: true
    t.index ["show_id", "slug"], name: "index_tracks_on_show_id_and_slug", unique: true
    t.index ["slug"], name: "index_tracks_on_slug"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "username", limit: 255, default: "", null: false
    t.string "crypted_password"
    t.string "salt"
    t.datetime "reset_password_token_expires_at"
    t.datetime "reset_password_email_sent_at"
    t.integer "access_count_to_reset_password_page", default: 0
    t.string "remember_me_token"
    t.datetime "remember_me_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["remember_me_token"], name: "index_users_on_remember_me_token"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "venue_renames", force: :cascade do |t|
    t.integer "venue_id"
    t.string "name", null: false
    t.date "renamed_on", null: false
    t.index ["name", "renamed_on"], name: "index_venue_renames_on_name_and_renamed_on", unique: true
    t.index ["venue_id"], name: "index_venue_renames_on_venue_id"
  end

  create_table "venues", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "city", limit: 255, null: false
    t.string "state", limit: 255, null: false
    t.string "country", limit: 255, null: false
    t.string "slug", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "shows_count", default: 0
    t.float "latitude"
    t.float "longitude"
    t.string "abbrev", limit: 255
    t.index ["name", "city"], name: "index_venues_on_name_and_city", unique: true
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end
end
