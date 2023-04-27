# frozen_string_literal: true
module Phishin::V2::Helpers::ApiHelpers
  extend Grape::API::Helpers

  params :pagination do
    optional :limit, type: Integer, default: 20, desc: 'Number of items to return'
    optional :offset, type: Integer, default: 0, desc: 'Number of items to skip'
    optional :sort_attr, type: String, default: 'date', desc: 'Attribute to sort by'
    optional :sort_dir, type: String, values: %w[asc desc], default: 'desc', desc: 'Sort direction'
  end

  params :show_filters do
    optional :year, type: Integer, desc: 'Filter by year'
    optional :era, type: Integer, desc: 'Filter by era'
    optional :era, type: Integer, desc: 'Filter by era'
  end

  def paginate(klass)
    klass.order("#{params[:sort_attr]} #{params[:sort_dir]}")
         .offset(params[:offset])
         .limit(params[:limit])
  end

  def authorize
    raise 'Unauthorized' unless request.headers['Authorization']&.start_with?('Bearer ')
    key = request.headers['Authorization'].split('Bearer ')[1]
    raise 'Unauthorized' unless ApiKey.active.exists?(key:)
  end
end
