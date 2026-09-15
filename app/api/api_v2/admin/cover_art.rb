class ApiV2::Admin::CoverArt < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      route_param :date, requirements: DATE[:date] do
        namespace :cover_art do
          desc "Regenerate the cover art prompt", hidden: true
          post :regenerate_prompt do
            enqueue_job("cover_art_prompt", Admin::RegenerateCoverArtPromptJob, show: admin_show)
          end

          desc "Generate a cover art candidate", hidden: true
          params do
            optional :prompt, type: String
          end
          post :generate do
            show = admin_show
            if params[:prompt].blank? && show.cover_art_prompt.blank? &&
               show.cover_art_parent_show_id.blank?
              error!({ message: "Set a cover art prompt first" }, 422)
            end
            enqueue_job("cover_art_generate", Admin::GenerateCoverArtJob, show:, args: [ params[:prompt].presence ])
          end

          desc "Upload a cover art candidate", hidden: true
          params do
            requires :signed_id, type: String
          end
          post :upload do
            show = admin_show
            show.cover_art_candidates.attach(find_signed_blob(params[:signed_id]))
            status 201
            { cover_art: cover_art_payload(show.reload) }
          end

          desc "AI-edit an image into a new candidate", hidden: true
          params do
            requires :source_blob_key, type: String
            requires :edit_prompt, type: String
          end
          post :ai_edit do
            show = admin_show
            validate_source_blob_key!(show, params[:source_blob_key])
            enqueue_job("cover_art_edit", Admin::EditCoverArtJob, show:,
                        args: [ params[:source_blob_key], params[:edit_prompt] ])
          end

          desc "Apply a candidate as the show's cover art", hidden: true
          params do
            requires :blob_key, type: String
            optional :zoom, type: Integer, values: 0..50, default: 0
          end
          post :select do
            show = admin_show
            validate_candidate_blob_key!(show, params[:blob_key])
            enqueue_job("cover_art_select", Admin::SelectCoverArtJob, show:, args: [ params[:blob_key], params[:zoom] ])
          end

          desc "Remove a candidate", hidden: true
          params do
            requires :blob_key, type: String
          end
          delete :candidates do
            show = admin_show
            validate_candidate_blob_key!(show, params[:blob_key])
            attachments = show.cover_art_candidates_attachments.includes(:blob)
                              .select { |a| a.blob.key == params[:blob_key] }
            attachments.each { |attachment| Admin::Blobs.detach(attachment) }
            status 204
            body false
          end
        end
      end
    end
  end

  helpers do
    def validate_source_blob_key!(show, key)
      return if candidate_blob_key?(show, key)
      return if show.cover_art.attached? && show.cover_art.blob.key == key
      error!({ message: "Unknown source image for #{show.date}" }, 422)
    end

    def validate_candidate_blob_key!(show, key)
      return if candidate_blob_key?(show, key)
      error!({ message: "Unknown candidate for #{show.date}" }, 422)
    end

    def candidate_blob_key?(show, key)
      show.cover_art_candidates_attachments.includes(:blob)
          .any? { |attachment| attachment.blob.key == key }
    end
  end
end
