class ApiV2::Tags < ApiV2::Base
  resource :tags do
    desc "Return a list of Tags" do
      detail "Fetches a list of all Tags, sorted alphabetically by name"
      success ApiV2::Entities::Tag
    end

    get do
      tags = Tag.order(name: :asc)
      present tags, with: ApiV2::Entities::Tag
    end
  end
end
