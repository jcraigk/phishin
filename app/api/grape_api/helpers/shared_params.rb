module GrapeApi::Helpers::SharedParams
  extend Grape::API::Helpers

  SORT_OPTIONS = [ "date", "likes_count", "duration" ]

  params :sort_and_pagination do
    optional :sort,
            type: String,
            desc: "Sort by attribute and direction (e.g., 'date:desc', 'likes_count:desc')",
            default: "date:desc"
    optional :page,
            type: Integer,
            desc: "Page number for pagination",
            default: 1
    optional :per_page,
            type: Integer,
            desc: "Number of items per page for pagination",
            default: 10
  end
end
