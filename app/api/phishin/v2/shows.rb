# frozen_string_literal: true
class Phishin::V2::Shows < Phishin::V2::Base
  helpers Phishin::V2::Helpers::ApiHelpers # TODO: Move this
  before { authorize }

  resource :shows do

    # /shows
    resource do
      desc 'Return a page of show (musical concert) data' do
        named 'Shows Index'
        summary 'Return a list of shows (musical concerts), optionally paginated and filtered'
        success Phishin::V2::Entities::Show
        is_array true
        # failure [[401, 'Unauthorized', 'Entities::Error']]
        headers Authorization: {
          description: 'Bearer token to authenticate request',
          required: true
        }
      end
      params { use :pagination, :show_filters }
      get { Phishin::V2::Entities::Show.represent(paginate(Show)) }
    end

    # /shows/:id_or_date
    route_param :id_or_date do
      desc 'Return data for a specific concert' do
        summary 'Return data for a specific concert, identified by ID or date (YYYY-MM-DD)'
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
