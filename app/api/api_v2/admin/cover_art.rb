class ApiV2::Admin::CoverArt < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    desc "Cover art hue and style options", hidden: true
    get :cover_art_options do
      { hues: CoverArtPromptService::HUES, styles: CoverArtPromptService::STYLES }
    end

    resource :shows do
      route_param :date, requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        namespace :cover_art do
          desc "Regenerate the cover art prompt", hidden: true
          post :regenerate_prompt do
            show = admin_show
            job = AdminJob.create!(kind: "cover_art_prompt", show:)
            Admin::RegenerateCoverArtPromptJob.perform_async(show.id, job.id)
            status 201
            { job_id: job.id }
          end

          # Generation costs money per call, so a show with neither a prompt nor a
          # parent to copy is rejected here rather than enqueued to fail later.
          desc "Generate a cover art candidate", hidden: true
          post :generate do
            show = admin_show
            if show.cover_art_prompt.blank? && show.cover_art_parent_show_id.blank?
              error!({ message: "Set a cover art prompt first" }, 422)
            end
            job = AdminJob.create!(kind: "cover_art_generate", show:)
            Admin::GenerateCoverArtJob.perform_async(show.id, job.id)
            status 201
            { job_id: job.id }
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

          # The source may be a candidate or the show's current cover art, but it
          # must be an image this show already owns: an arbitrary blob key would
          # let an edit read any file in storage.
          desc "AI-edit an image into a new candidate", hidden: true
          params do
            requires :source_blob_key, type: String
            requires :edit_prompt, type: String
          end
          post :ai_edit do
            show = admin_show
            validate_source_blob_key!(show, params[:source_blob_key])
            job = AdminJob.create!(kind: "cover_art_edit", show:)
            Admin::EditCoverArtJob.perform_async(
              show.id, job.id, params[:source_blob_key], params[:edit_prompt]
            )
            status 201
            { job_id: job.id }
          end

          # The candidate must be one this show holds; the job re-checks the key
          # for itself, but rejecting it here saves the admin a failed job.
          desc "Apply a candidate as the show's cover art", hidden: true
          params do
            requires :blob_key, type: String
            optional :zoom, type: Integer, values: 0..50, default: 0
          end
          post :select do
            show = admin_show
            validate_candidate_blob_key!(show, params[:blob_key])
            job = AdminJob.create!(kind: "cover_art_select", show:)
            Admin::SelectCoverArtJob.perform_async(
              show.id, job.id, params[:blob_key], params[:zoom]
            )
            status 201
            { job_id: job.id }
          end

          # Purge only when nothing else points at the blob: a parent-linked
          # candidate shares the parent show's cover art blob, and purging that
          # would take the parent's art with it.
          desc "Remove a candidate", hidden: true
          params do
            requires :blob_key, type: String
          end
          delete :candidates do
            show = admin_show
            validate_candidate_blob_key!(show, params[:blob_key])
            attachments = show.cover_art_candidates_attachments.includes(:blob)
                              .select { |a| a.blob.key == params[:blob_key] }
            attachments.each do |attachment|
              blob_in_use = ActiveStorage::Attachment
                            .where(blob_id: attachment.blob_id)
                            .where.not(id: attachment.id)
                            .exists?
              blob_in_use ? attachment.destroy : attachment.purge
            end
            status 204
            body false
          end
        end
      end
    end
  end

  helpers do
    def find_signed_blob(signed_id)
      ActiveStorage::Blob.find_signed!(signed_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      error!({ message: "Unknown upload: #{signed_id}" }, 422)
    end

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
