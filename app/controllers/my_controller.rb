class MyController < ApplicationController
  def my_shows
    return unless current_user
    validate_sorting_for_my_shows

    @shows = paginated_shows
    @shows_likes = user_likes_for_shows(@shows)

    render_view
  end

  def my_tracks
    return unless current_user
    validate_sorting_for_my_tracks

    track_ids = Like.where(likable_type: "Track", user: current_user).map(&:likable_id)
    @tracks = Track.where(id: track_ids)
                   .includes(:show).order(@order_by)
                   .paginate(page: params[:page], per_page:)
    @tracks_likes = user_likes_for_tracks([ @tracks ])

    render_view
  end

  private

  def paginated_shows
    show_ids = Like.where(likable_type: "Show", user: current_user).map(&:likable_id)
    Show.published
        .where(id: show_ids)
        .includes(:tracks)
        .order(@order_by)
        .paginate(page: params[:page], per_page:)
  end

  def validate_sorting_for_my_shows # rubocop:disable Metrics/MethodLength
    params[:sort] = "date desc" unless
      params[:sort].in?([ "date desc", "date asc", "title", "likes", "duration" ])
    @order_by =
      case params[:sort]
      when "date asc", "date desc"
        params[:sort]
      when "title"
        "title desc, date desc"
      when "likes"
        "likes_count desc, date desc"
      when "duration"
        "duration desc, date desc"
      end
  end

  def validate_sorting_for_my_tracks # rubocop:disable Metrics/MethodLength
    params[:sort] = "shows.date desc" unless
      params[:sort].in?([ "title", "shows.date desc", "shows.date asc", "likes", "duration" ])
    @order_by =
      case params[:sort]
      when "title"
        "title asc"
      when "shows.date asc", "shows.date desc"
        params[:sort]
      when "likes"
        "likes_count desc"
      when "duration"
        "duration desc"
      end
  end
end
