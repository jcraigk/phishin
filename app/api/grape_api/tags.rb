class GrapeApi::Tags < GrapeApi::Base
  resource :tags do
    desc "Return a list of all tags"
    get do
      tags = Tag.order(name: :asc)
      present tags, with: GrapeApi::Entities::Tag
    end
  end
end
