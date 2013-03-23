class MapController < ApplicationController

  def search
    if params[:lat].present? and params[:lng].present? and params[:distance].present?
      
    else
      render json: { success: false, msg: 'No results matched your criteria'}
    end
  end

end