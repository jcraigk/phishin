require_relative "entities/show" # TODO: Remove this

class Api::V2::Shows < Grape::API
  resource :shows do
    desc "Return a list of shows"
    get do
      shows = Show.all
      present shows, with: Api::V2::Entities::Show
    end

    desc "Return a specific show"
    params do
      requires :id, type: Integer, desc: "ID of the show"
    end
    get ":id" do
      show = Show.find(params[:id])
      present show, with: Api::V2::Entities::Show
    end
  end
end
