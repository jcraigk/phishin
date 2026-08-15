require "rails_helper"

# Grape does not inherit `before` blocks or helpers from a superclass, so every
# admin endpoint class must declare `helpers ApiV2::Helpers::AdminHelper` and
# `before { authenticate_admin! }` in its own body. Forgetting either ships an
# unauthenticated endpoint with no visible symptom, so this walks the mounted
# routes rather than trusting per-file review.
RSpec.describe "Admin route auth audit" do
  it "rejects anonymous requests on every admin route" do
    routes = ApiV2::Api.routes.map { |r| [ r.request_method, r.path.to_s ] }
                       .select { |_, path| path.include?("/admin/") }

    ungated = routes.filter_map do |method, path|
      concrete = "/api/v2" + path.sub("(.:format)", "")
                                 .sub("(.json)", "")
                                 .gsub(":date", "2024-07-19")
                                 .gsub(/:[a-z_]+/, "1")
      send(method.downcase, concrete)
      "#{method} #{concrete} => #{response.status}" unless [ 401, 403 ].include?(response.status)
    end

    expect(routes.size).to be >= 47
    expect(ungated).to eq([])
  end
end
