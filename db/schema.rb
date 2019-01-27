# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_01_27_220532) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "key", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_api_keys_on_email", unique: true
    t.index ["key"], name: "index_api_keys_on_key", unique: true
    t.index ["name"], name: "index_api_keys_on_name", unique: true
  end

  create_table "api_requests", force: :cascade do |t|
    t.integer "api_key_id"
    t.string "path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "likes", id: :serial, force: :cascade do |t|
    t.string "likable_type", limit: 255
    t.integer "likable_id"
    t.integer "user_id"
    t.datetime "created_at"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duration", default: 0
    t.index ["duration"], name: "index_playlists_on_duration"
    t.index ["name"], name: "index_playlists_on_name", unique: true
    t.index ["slug"], name: "index_playlists_on_slug", unique: true
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "show_tags", id: :serial, force: :cascade do |t|
    t.integer "show_id"
    t.integer "tag_id"
    t.datetime "created_at"
    t.text "notes"
    t.index ["notes"], name: "index_show_tags_on_notes"
    t.index ["show_id"], name: "index_show_tags_on_show_id"
    t.index ["tag_id", "show_id"], name: "index_show_tags_on_tag_id_and_show_id", unique: true
  end

  create_table "shows", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "remastered", default: false
    t.boolean "sbd", default: false
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
    t.index ["date"], name: "index_shows_on_date", unique: true
    t.index ["duration"], name: "index_shows_on_duration"
    t.index ["likes_count"], name: "index_shows_on_likes_count"
    t.index ["tour_id"], name: "index_shows_on_tour_id"
    t.index ["venue_id"], name: "index_shows_on_venue_id"
  end

  create_table "songs", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", limit: 255, null: false
    t.integer "tracks_count", default: 0
    t.integer "alias_for"
    t.string "lyrical_excerpt", limit: 255
    t.boolean "original", default: false, null: false
    t.index ["original"], name: "index_songs_on_original"
    t.index ["slug"], name: "index_songs_on_slug", unique: true
    t.index ["title"], name: "index_songs_on_title", unique: true
  end

  create_table "songs_tracks", id: :serial, force: :cascade do |t|
    t.integer "song_id"
    t.integer "track_id"
    t.index ["song_id"], name: "index_songs_tracks_on_song_id"
    t.index ["track_id", "song_id"], name: "index_songs_tracks_on_track_id_and_song_id", unique: true
    t.index ["track_id"], name: "index_songs_tracks_on_track_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "color", limit: 255, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "shows_count", default: 0
    t.index ["ends_on"], name: "index_tours_on_ends_on", unique: true
    t.index ["name"], name: "index_tours_on_name", unique: true
    t.index ["slug"], name: "index_tours_on_slug", unique: true
    t.index ["starts_on"], name: "index_tours_on_starts_on", unique: true
  end

  create_table "track_tags", id: :serial, force: :cascade do |t|
    t.integer "track_id"
    t.integer "tag_id"
    t.datetime "created_at"
    t.text "notes"
    t.integer "starts_at_second"
    t.integer "ends_at_second"
    t.text "transcript"
    t.index ["notes"], name: "index_track_tags_on_notes"
    t.index ["tag_id", "track_id"], name: "index_track_tags_on_tag_id_and_track_id", unique: true
    t.index ["tag_id"], name: "index_track_tags_on_tag_id"
    t.index ["track_id"], name: "index_track_tags_on_track_id"
  end

  create_table "tracks", id: :serial, force: :cascade do |t|
    t.integer "show_id"
    t.string "title", limit: 255, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "audio_file_file_name", limit: 255
    t.string "audio_file_content_type", limit: 255
    t.integer "audio_file_file_size"
    t.datetime "audio_file_updated_at"
    t.integer "duration"
    t.string "set", limit: 255, null: false
    t.integer "likes_count", default: 0
    t.string "slug", limit: 255, null: false
    t.integer "tags_count", default: 0
    t.index ["likes_count"], name: "index_tracks_on_likes_count"
    t.index ["show_id", "position"], name: "index_tracks_on_show_id_and_position", unique: true
    t.index ["show_id", "slug"], name: "index_tracks_on_show_id_and_slug", unique: true
    t.index ["slug"], name: "index_tracks_on_slug"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", limit: 255, default: "", null: false
    t.string "authentication_token", limit: 255
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "shows_count", default: 0
    t.float "latitude"
    t.float "longitude"
    t.string "abbrev", limit: 255
    t.index ["name", "city"], name: "index_venues_on_name_and_city", unique: true
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

end
