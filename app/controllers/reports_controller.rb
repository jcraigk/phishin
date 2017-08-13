class ReportsController < ApplicationController
  def missing_shows
    @missing_shows = Show.where('missing = ? and date < ?', true, Time.now)
                         .order('date desc')
                         .page(params[:page])
    render layout: false if request.xhr?
  end
end
