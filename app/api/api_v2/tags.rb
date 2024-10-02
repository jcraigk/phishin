class ApiV2::Tags < ApiV2::Base
  resource :tags do
    desc "Fetch a list of tags" do
      detail "Fetch a list of all tags, sorted alphabetically by name"
      success ApiV2::Entities::Tag
    end

    get do
      present tags, with: ApiV2::Entities::Tag
    end
  end

  helpers do
    def tags
      Rails.cache.fetch("api/v2/tags") do
        Tag.order(name: :asc)
      end
    end
  end
end
