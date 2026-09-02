class ApiV2::Admin::Taggings < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    desc "List all tags", hidden: true
    get :tags do
      {
        tags: Tag.order(:name).map { |tag| { id: tag.id, name: tag.name, group: tag.group } }
      }
    end

    resource :shows do
      desc "Check Phish.net sources for tag suggestions", hidden: true
      post ":date/pnet_tag_check", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        job = AdminJob.create!(kind: "pnet_tag_check", show:)
        Admin::PnetTagCheckJob.perform_async(show.id, job.id)
        status 201
        { job_id: job.id }
      end

      desc "Add a show tag", hidden: true
      params do
        requires :tag_id, type: Integer
        optional :notes, type: String
      end
      post ":date/show_tags", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        show.show_tags.create!(tag: Tag.find(params[:tag_id]), notes: params[:notes])
        status 201
        editor_payload(show.reload)
      end
    end

    resource :show_tags do
      desc "Update a show tag", hidden: true
      params do
        optional :notes, type: String
      end
      patch ":id" do
        show_tag = ShowTag.find(params[:id])
        show_tag.update!(declared(params, include_missing: false).except(:id))
        editor_payload(show_tag.show.reload)
      end

      desc "Remove a show tag", hidden: true
      delete ":id" do
        show_tag = ShowTag.find(params[:id])
        show = show_tag.show
        show_tag.destroy!
        editor_payload(show.reload)
      end
    end

    resource :tracks do
      desc "Add a track tag", hidden: true
      params do
        requires :tag_id, type: Integer
        optional :notes, type: String
        optional :starts_at_second, type: Integer
        optional :ends_at_second, type: Integer
        optional :transcript, type: String
      end
      post ":id/track_tags" do
        track = Track.find(params[:id])
        attrs = declared(params, include_missing: false).except(:id, :tag_id)
        track.track_tags.create!(attrs.merge(tag: Tag.find(params[:tag_id])))
        status 201
        track_payload(track.reload)
      end
    end

    resource :track_tags do
      desc "Update a track tag", hidden: true
      params do
        optional :notes, type: String
        optional :starts_at_second, type: Integer
        optional :ends_at_second, type: Integer
        optional :transcript, type: String
        optional :orphaned, type: Boolean, values: [ false ]
      end
      patch ":id" do
        track_tag = TrackTag.find(params[:id])
        updates = declared(params, include_missing: false).except(:id).symbolize_keys
        updates.delete(:orphaned)
        updates.merge!(orphaned_at: nil, orphan_reason: nil) if params.key?(:orphaned)
        track_tag.update!(updates)
        track_payload(track_tag.track.reload)
      end

      desc "Remove a track tag", hidden: true
      delete ":id" do
        track_tag = TrackTag.find(params[:id])
        track = track_tag.track
        track_tag.destroy!
        track_payload(track.reload)
      end
    end
  end
end
