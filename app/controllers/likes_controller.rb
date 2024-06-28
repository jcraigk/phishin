class LikesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def toggle_like
    return respond_sign_in unless current_user
    return respond_with_invalid_likable unless likable
    respond_with_status(like_status)
  end

  private

  def respond_sign_in
    render json: { success: false, msg: 'You must be signed in to submit Likes' }
  end

  def like_status
    if existing_like
      existing_like.destroy
      return false
    end

    likable.likes.build(user: current_user).save!
    true
  end

  def respond_with_status(liked)
    msg = "#{liked ? 'Like' : 'Unlike'} acknowledged"
    render json: {
      success: true,
      msg:,
      liked:,
      likes_count: likable.likes_count
    }
  end

  def respond_with_invalid_likable
    render json: {
      success: false,
      msg: "Invalid likable object specified (#{params[:likable_type]})"
    }
  end

  def existing_like
    @existing_like ||= likable.likes.find_by(user: current_user)
  end

  def likable
    @likable ||= likable_type.classify.constantize.find_by(id: params[:likable_id])
  end

  def likable_type
    params[:likable_type].in?(%w[show track]) ? params[:likable_type] : 'show'
  end
end
