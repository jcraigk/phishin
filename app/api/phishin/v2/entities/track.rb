# frozen_string_literal: true
class Phishin::V2::Entities::Track < Phishin::V2::Entities::Base
  expose :data do
    expose :id,
           documentation: { type: 'Integer', desc: 'ID of the track' }
    expose :slug,
           documentation: { type: 'String', desc: 'Slug of the track' }
    expose :show_id,
           documentation: { type: 'Date', desc: 'ID of the show' }
    expose :title,
           documentation: { type: 'String', desc: 'Title of the track' }
    expose :position,
           documentation: { type: 'Integer', desc: 'Position of the track in the show' }
    expose :duration,
           documentation: { type: 'Integer', desc: 'Duration of the track in milliseconds' }
    expose :jam_starts_at_second,
           documentation: { type: 'Integer', desc: 'Second at which the jam starts' }
    expose :set,
           documentation: { type: 'Integer', desc: 'Set number of the track' }
    expose :likes_count,
           documentation: { type: 'Integer', desc: 'Number of listener likes' }
    expose :songs_count,
           documentation: { type: 'Array', desc: 'Number of songs contained in the track' }
    expose :mp3,
           documentation: { type: 'String', desc: 'URL of the MP3 audio file' }
    expose :waveform_image,
           documentation: { type: 'String', desc: 'URL of the PNG waveform image' }
    expose :updated_at,
           documentation: { type: 'Date', desc: 'When the database record was last updated' }

    expose :show,
           documentation: {
             type: 'Phishin::V2::Entities::Show',
             desc: 'Show containing the track'
           },
           using: Phishin::V2::Entities::Show,
           if: ->(_, opts) { opts[:style] == :full }
    expose :tags,
           documentation: {
             type: 'Phishin::V2::Entities::Tag',
             desc: 'Annotation tags associated with the track'
           },
           using: Phishin::V2::Entities::Tag,
           if: ->(_, opts) { opts[:style] == :full }
    expose :songs,
           documentation: {
             type: 'Phishin::V2::Entities::Songs',
             desc: 'Songs contained in the track'
           },
           using: Phishin::V2::Entities::Song,
           if: ->(_, opts) { opts[:style] == :full }
  end
end
