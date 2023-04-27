# frozen_string_literal: true
class Phishin::V2::Entities::Venue < Phishin::V2::Entities::Base
  expose :id,
         documentation: { type: 'Integer', desc: 'ID of the venue' }
  expose :slug,
         documentation: { type: 'String', desc: 'Slug of the venue' }
  expose :name,
         documentation: { type: 'String', desc: 'Original name of the venue' }
  expose :other_names,
         documentation: { type: 'String', desc: 'Alternate venue names/brandings' }
  expose :location,
         documentation: { type: 'String', desc: 'Common name of venue location' }
  expose :latitude,
         documentation: { type: 'String', desc: 'Latitude of venue' }
  expose :longitude,
         documentation: { type: 'Integer', desc: 'Longitude of venue' }
  expose :updated_at,
         documentation: { type: 'Date', desc: 'When the database record was last updated' }
end
