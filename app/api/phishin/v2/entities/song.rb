# frozen_string_literal: true
class Phishin::V2::Entities::Song < Phishin::V2::Entities::Base
  expose :data do
    expose :id,
           documentation: { type: 'Integer', desc: 'ID of the song' }
    expose :slug,
           documentation: { type: 'String', desc: 'Slug of the song' }
    expose :title,
           documentation: { type: 'String', desc: 'Title of the song' }
    expose :alias,
           documentation: { type: 'String', desc: 'Alias of the song title' }
    expose :original,
           documentation: {
             type: 'Boolean',
             desc: 'Whether the song is an original composition or a cover of another artist'
           }
    expose :artist,
           documentation: { type: 'String', desc: 'Original artist of the song, if a cover' }
    expose :lyrics,
           documentation: { type: 'String', desc: 'Lyrics of the song' }
    expose :tracks_count,
           documentation: {
             type: 'Integer',
             desc: 'Number of tracks that contain this song'
           }
    expose :updated_at,
           documentation: { type: 'Date', desc: 'When the database record was last updated' }

    expose :tracks,
           documentation: {
             type: 'Phishin::V2::Entities::Track',
             desc: 'Tracks that contain this song'
           },
           using: Phishin::V2::Entities::Track,
           if: ->(_, opts) { opts[:style] == :full }
  end
end
