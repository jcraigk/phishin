class LikesController < ApplicationController
  
  before_filter :authorize_user!
  before_filter :require_xhr!
  
  def toggle_like
    begin
      if likable = find_likable
        if like = likable.likes.where(user_id: current_user.id).first
          like.destroy
          liked = false
          likes_count = likable.likes_count - 1
        else
          blah = likable.likes.build(user_id: current_user.id).save!
          liked = true
          likes_count = likable.likes_count + 1
        end
        msg = "#{(liked ? 'Like' : 'Unlike')} acknowledged"
        render :json => { success: true, msg: msg, liked: liked, likes_count: likes_count }
      else
        render :json => { success: false, msg: "Invalid likable object specified (#{params[:likable_type]})" }
      end
    rescue
      render :json => { success: false, msg: 'Error while acknowledging like' }
    end
  end
  
  private
  
  def authorize_user!
    render :json => { success: false, msg: 'You must be signed in to submit Likes' } and return unless current_user
  end
  
  def find_likable
    params[:likable_type].classify.constantize.where(id: params[:likable_id]).first if params[:likable_type] and params[:likable_id]
  end
  
end