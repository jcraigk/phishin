require 'shrine'
require 'shrine/storage/file_system'

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new('tmp/cache'),
  store: Shrine::Storage::FileSystem.new(APP_CONTENT_PATH, prefix: 'tracks/audio_files')
}

Shrine.plugin :activerecord
Shrine.plugin :determine_mime_type, analyzer: :marcel
Shrine.plugin :model, cache: false
