# frozen_string_literal: true
class Phishin::V2::Shows < Grape::API
  # /shows
  resource :shows do
    resource do
      desc 'Return a page of Show (musical concert) metadata' do
        summary 'summary'
        detail 'Request'
        # params  API::Entities::Status.documentation
        success Phishin::V2::Entities::Show
        # failure [[401, 'Unauthorized', 'Entities::Error']]
        named 'Shows index'
        # headers XAuthToken: {
        #           description: 'Validates your identity',
        #           required: true
        #         },
        #         XOptionalHeader: {
        #           description: 'Not really needed',
        #           required: false
        #         }
        is_array true
        produces ['application/json']
        consumes ['application/json']
        # tags ['tag1', 'tag2']
      end
      get do
        present Show.limit(10)
      end
    end

    # /shows/:id
    route_param :id do
      desc 'Return metadata for a specific show (musical concert)' do
        summary 'summary'
        detail 'Request'
        # params  API::Entities::Status.documentation
        success Phishin::V2::Entities::Show
        # failure [[401, 'Unauthorized', 'Entities::Error']]
        named 'Show show'
        is_array true
        produces ['application/json']
        consumes ['application/json']
        # tags ['tag1', 'tag2']
      end
      get do
        present Show.find(params[:id]), style: :full
      end
    end
  end
end
