# encoding: UTF-8
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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130223222601) do

  create_table "albums", :force => true do |t|
    t.string   "name"
    t.string   "md5"
    t.boolean  "is_custom_playlist",    :default => false
    t.datetime "completed_at"
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
    t.string   "zip_file_file_name"
    t.string   "zip_file_content_type"
    t.integer  "zip_file_file_size"
    t.datetime "zip_file_updated_at"
  end

  add_index "albums", ["md5"], :name => "index_albums_on_md5"

  create_table "rails_admin_histories", :force => true do |t|
    t.text     "message"
    t.string   "username"
    t.integer  "item"
    t.string   "table"
    t.integer  "month",      :limit => 2
    t.integer  "year",       :limit => 8
    t.datetime "created_at",              :null => false
    t.datetime "updated_at",              :null => false
  end

  add_index "rails_admin_histories", ["item", "table", "month", "year"], :name => "index_rails_admin_histories"

  create_table "section_markers", :force => true do |t|
    t.string   "title"
    t.integer  "position"
    t.integer  "track_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "shows", :force => true do |t|
    t.date     "date"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.string   "location"
    t.boolean  "remastered", :default => false
    t.boolean  "sbd",        :default => false
    t.integer  "venue_id"
    t.integer  "tour_id"
  end

  add_index "shows", ["tour_id"], :name => "index_shows_on_tour_id"
  add_index "shows", ["venue_id"], :name => "index_shows_on_venue_id"

  create_table "songs", :force => true do |t|
    t.string   "title"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.string   "slug"
    t.integer  "tracks_count", :default => 0
    t.integer  "alias_for"
  end

  create_table "songs_tracks", :force => true do |t|
    t.integer "song_id"
    t.integer "track_id"
  end

  create_table "tours", :force => true do |t|
    t.string   "name"
    t.date     "starts_on"
    t.date     "ends_on"
    t.string   "slug"
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.integer  "shows_count", :default => 0
  end

  add_index "tours", ["name"], :name => "index_tours_on_name"
  add_index "tours", ["starts_on"], :name => "index_tours_on_starts_on"

  create_table "tracks", :force => true do |t|
    t.integer  "show_id"
    t.string   "title"
    t.integer  "position"
    t.datetime "created_at",              :null => false
    t.datetime "updated_at",              :null => false
    t.string   "audio_file_file_name"
    t.string   "audio_file_content_type"
    t.integer  "audio_file_file_size"
    t.datetime "audio_file_updated_at"
    t.integer  "duration"
    t.string   "set"
  end

  create_table "venues", :force => true do |t|
    t.string   "name"
    t.string   "past_names"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "slug"
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.integer  "shows_count", :default => 0
  end

  add_index "venues", ["name"], :name => "index_venues_on_name"

end
