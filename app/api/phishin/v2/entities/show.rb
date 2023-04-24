# frozen_string_literal: true
class Phishin::V2::Entities::Show < Phishin::V2::Entities::Base
  expose :data do
    expose :id,
           documentation: { type: 'Integer', desc: 'ID of the show' }
    expose :era,
           documentation: { type: 'Date', desc: 'The era during which the show took place' }
    expose :date,
           documentation: { type: 'Date', desc: 'Date of the show' }
    expose :duration,
           documentation: { type: 'Integer', desc: 'Duration of the show in seconds' }
    expose :incomplete,
           documentation: {
             type: 'Boolean',
             desc: 'Whether the audio source for the show is incomplete'
           }
    expose :likes_count,
           documentation: { type: 'Integer', desc: 'Number of user likes for the show' }
    expose :venue_name,
           documentation: {
             type: 'String',
             desc: 'Contemporary name of the venue at which the show took place'
           }
    expose :venue_location,
           documentation: {
             type: 'String',
             desc: 'Common name of the location of the venue at which the show took place'
           }
    expose :updated_at,
           documentation: { type: 'Date', desc: 'When the database record was last updated' }
    expose :taper_notes,
           documentation: { type: 'String', desc: 'Taper notes for the show' }

    expose :tags,
           documentation: {
             type: 'Phishin::V2::Entities::Tag',
             desc: 'Annotation tags associated with the show'
           },
           using: Phishin::V2::Entities::Tag,
           if: ->(_, opts) { opts[:style] == :full }
    expose :tour,
           documentation: {
             type: 'Phishin::V2::Entities::Tour',
             desc: 'Tour during which the show took place'
           },
           using: Phishin::V2::Entities::Tour,
           if: ->(_, opts) { opts[:style] == :full }
    expose :venue,
           documentation: {
             type: 'Phishin::V2::Entities::Venue',
             desc: 'Venue at which the show took place'
           },
           using: Phishin::V2::Entities::Venue,
           if: ->(_, opts) { opts[:style] == :full }
    expose :tracks,
           documentation: {
             type: 'Phishin::V2::Entities::Track',
             desc: 'Audio tracks contained in the show'
           },
           using: Phishin::V2::Entities::Track,
           if: ->(_, opts) { opts[:style] == :full }
  end

  private

  def era
    return '1.0' if object.date.year.in?(1983..1987)
    ERAS.find { |_era, years| years.include?(object.date.year.to_s) }.first
  end

  def venue_location
    object.venue.location
  end
end
