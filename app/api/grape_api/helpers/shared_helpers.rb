module GrapeApi::Helpers::SharedHelpers
  extend Grape::API::Helpers

  def apply_sorting(relation, sort_options)
    attribute, direction = params[:sort].split(":")
    direction ||= "asc"
    if sort_options.include?(attribute) && [ "asc", "desc" ].include?(direction)
      relation.order("#{attribute} #{direction}")
    else
      error!("Invalid sort parameter", 400)
    end
  end
end
