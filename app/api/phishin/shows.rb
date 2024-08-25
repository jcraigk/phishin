class Phishin::Shows < Grape::API
  resource :shows do
    desc "Return a list of shows"
    get do
      shows = Show.all
      present shows, with: Phishin::Entities::ShowEntity
    end

    desc "Return a specific show"
    params do
      requires :id, type: Integer, desc: "ID of the show"
    end
    get ":id" do
      show = Show.find(params[:id])
      present show, with: Phishin::Entities::ShowEntity
    end
  end
end
