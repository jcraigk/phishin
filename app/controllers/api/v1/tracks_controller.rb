class Api::V1::TracksController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show

  def index
    tracks = params[:tag] ? Track.tagged_with(params[:tag]) : track_scope
    respond_with_success get_data_for(tracks)
  end

  def show
    respond_with_success Track.includes(:tags, :show).find(params[:id])
  end

  private

  def track_scope
    Track.joins(:show).where.not(shows: { audio_status: 'missing' }).includes(:show, :songs, :tags)
  end
end
