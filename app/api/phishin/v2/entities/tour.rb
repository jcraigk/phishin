# frozen_string_literal: true
class Phishin::V2::Entities::Tour < Phishin::V2::Entities::Base
  expose :data do
    expose :id,
           documentation: { type: 'Integer', desc: 'ID of the tour' }
    expose :slug,
           documentation: { type: 'String', desc: 'Slug of the tour' }
    expose :name,
           documentation: { type: 'String', desc: 'Name of the tour' }
    expose :starts_on,
           documentation: { type: 'Date', desc: 'First date of the tour' }
    expose :starts_on,
           documentation: { type: 'Date', desc: 'Last date of the tour' }
    expose :shows_count,
           documentation: {
             type: 'Integer',
             desc: 'Number of shows in the tour'
           }
    expose :updated_at,
           documentation: { type: 'Date', desc: 'When the database record was last updated' }

    expose :shows,
           documentation: {
             type: 'Phishin::V2::Entities::Show',
             desc: 'Shows in the tour'
           },
           using: Phishin::V2::Entities::Show,
           if: ->(_, opts) { opts[:style] == :full }
  end
end
