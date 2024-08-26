module ApiV2::Helpers::SharedParams
  extend Grape::API::Helpers

  params :pagination do
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
