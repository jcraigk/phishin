# frozen_string_literal: true
class Phishin::V2::Entities::Tag < Phishin::V2::Entities::Base
  expose :data do
    expose :id,
           documentation: { type: 'Integer', desc: 'ID of the tag' }
    expose :slug,
           documentation: { type: 'String', desc: 'Slug of the tag' }
    expose :name,
           documentation: { type: 'String', desc: 'Name of the tag' }
    expose :group,
           documentation: { type: 'String', desc: 'Name of the logical group containing the tag' }
    expose :color,
           documentation: { type: 'String', desc: 'Color of the tag in hex' }
    expose :priority,
           documentation: { type: 'Integer', desc: 'Display priority of the tag' }
    expose :description,
           documentation: { type: 'String', desc: 'Description of the tag' }
    expose :updated_at,
           documentation: { type: 'Date', desc: 'When the database record was last updated' }
  end
end
