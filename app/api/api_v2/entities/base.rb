class ApiV2::Entities::Base < Grape::Entity
  private

  format_with :iso8601 do |date|
    date.iso8601
  end
end
