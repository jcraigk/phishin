class ApiV2::Likes < ApiV2::Base
  resource :likes do
    desc "Like or unlike a show, track, or playlist" do
      detail "Creates a like for a show, track, or playlist. Restricted to authenticated users."
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
               values: %w[Show Track Playlist]
      requires :likable_id,
               type: Integer,
               desc: "ID of the likable object"
    end
    post do
      authenticate!
      return error!({ message: "Invalid likable entity" }, 422) unless likable
      likable.likes.create!(user: current_user)
    end

    desc "Unlike a show, track, or playlist" do
      detail "Removes a like for a show, track, or playlist. Restricted to authenticated users."
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
               values: %w[Show Track Playlist]
      requires :likable_id,
               type: Integer,
               desc: "ID of the likable object"
    end
    delete do
      authenticate!
      return error!({ message: "Invalid likable entity" }, 422) unless likable
      existing_like = likable.likes.find_by(user: current_user)
      return error!({ message: "Like not found" }, 404) unless existing_like
      existing_like.destroy
      status 204
    end
  end

  helpers do
    def likable
      likable_class =
        case params[:likable_type]
        when "Show" then Show
        when "Track" then Track
        when "Playlist" then Playlist
        else return nil
        end
      likable_class.find_by(id: params[:likable_id])
    end
  end
end
