class GrapeApi::Tags < GrapeApi::Base
  resource :tags do
    desc "Return a list of Tags" do
      detail "Fetches a list of all Tags, sorted alphabetically by name"
      success GrapeApi::Entities::Tag
    end

    get do
      tags = Tag.order(name: :asc)
      present tags, with: GrapeApi::Entities::Tag
    end
  end
end
