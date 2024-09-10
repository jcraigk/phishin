class ApiV2::Likes < ApiV2::Base
  resource :likes do
    desc "Like or unlike a show or track" do
      detail "Creates a like for a show or track, restricted to authenticated users"
      success [ { code: 201 } ]
      failure [
        [ 401, "Unauthorized", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ],
        [ 422, "Unprocessable Entity", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :likable_type,
               type: String,
               desc: "Type of the likable object",
               values: %w[Show Track]
      requires :likable_id,
               type: Integer,
               desc: "ID of the likable object"
    end
    post do
      authenticate!
      return error!({ message: "Invalid show or track" }, 422) unless likable
      likable.likes.create!(user: current_user)
    end

    desc "Unlike a show or track" do
      detail "Removes a like for a show or track, restricted to authenticated users"
      success [ { code: 204 } ]
      failure [
        [ 401, "Unauthorized", ApiV2::Entities::ApiResponse ],
        [ 404, "Not Found", ApiV2::Entities::ApiResponse ],
        [ 422, "Unprocessable Entity", ApiV2::Entities::ApiResponse ]
      ]
    end
    params do
      requires :likable_type,
               type: String,
               desc: "Type of the likable object",
               values: %w[Show Track]
      requires :likable_id,
               type: Integer,
               desc: "ID of the likable object"
    end
    delete do
      authenticate!
      return error!({ message: "Invalid show or track" }, 422) unless likable
      existing_like = likable.likes.find_by(user: current_user)
      return error!({ message: "Like not found" }, 404) unless existing_like
      existing_like.destroy
      status 204
    end
  end

  helpers do
    def likable
      params[:likable_type].classify.constantize.find_by(id: params[:likable_id])
    end
  end
end
