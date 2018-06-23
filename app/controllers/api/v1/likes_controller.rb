# frozen_string_literal: true
class Api::V1::LikesController < Api::V1::ApiController
  before_action :authenticate_user_from_token!, except: %i[top_shows top_tracks]

  caches_action :top_tracks, expires_in: CACHE_TTL
  caches_action :top_shows, expires_in: CACHE_TTL

  # Return all likes for current user
  def user_likes
    respond_with_success_simple(
      show_ids: show_likes,
      track_ids: track_likes
    )
  end

  # Submit a like for a show or track
  # Requires :likable_type, :likable_id
  def like
    if params[:likable_type] && params[:likable_id]
      likable = find_likable
      if likable.likes.where(user: current_user).first
        respond_with_failure 'Entity already liked by current user'
      else
        likable.likes.build(user: current_user).save!
        respond_with_success_simple
      end
    else
      respond_with_failure 'Invalid request'
    end
  end

  # Submit an unlike for a show or track
  # Requires :likable_type, :likable_id
  def unlike
    if params[:likable_type] && params[:likable_id]
      likable = find_likable
      if (like = likable.likes.where(user: current_user).first)
        like.destroy
        respond_with_success_simple
      else
        respond_with_failure 'Entity not liked by current user'
      end
    else
      respond_with_failure 'Invalid request'
    end
  end

  # Return list of most liked shows overall
  def top_shows
    respond_with_success shows
  end

  # Return list of most liked tracks overall
  def top_tracks
    tracks = Track.where('likes_count > 0').order('likes_count desc, title asc').includes(:show).limit(40)
    respond_with_success tracks.map(&:as_json_api)
  end

  private

  def shows
    Show.avail
        .where('likes_count > 0')
        .order(likes_count: :desc, date: :desc)
        .limit(40)
  end

  def likes
    @likes ||= Like.where(user: current_user).all
  end

  def show_likes
    @likes
      .select { |like| like.likable_type == 'Show' }
      .map(&:likable_id)
  end

  def track_likes
    @likes
      .select { |like| like.likable_type == 'Track' }
      .map(&:likable_id)
  end

  def find_likable
    return unless params[:likable_type] && params[:likable_id]
    params[:likable_type]
      .classify
      .constantize
      .where(id: params[:likable_id])
      .first
  end
end
