class ApiV2::Admin::Shows < ApiV2::Admin::Base
  helpers ApiV2::Helpers::AdminHelper

  before { authenticate_admin! }

  namespace :admin do
    resource :shows do
      desc "List shows for admin", hidden: true
      params do
        optional :published, type: Boolean, desc: "Filter by published state"
      end
      get do
        shows = Show.order(date: :desc)
        shows = shows.where(published: params[:published]) unless params[:published].nil?
        {
          shows: shows.limit(500).map { |show| show_summary(show) }
        }
      end

      desc "Create a draft show", hidden: true
      params do
        requires :date, type: String, regexp: /\A\d{4}-\d{2}-\d{2}\z/
      end
      post do
        if Show.exists?(date: params[:date])
          error!({ message: "Show already exists for #{params[:date]}" }, 409)
        end
        Show.create!(date: params[:date], published: false, audio_status: "missing")
        status 201
        { date: params[:date] }
      end

      desc "Fetch a show for editing", hidden: true
      get ":date", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        editor_payload(admin_show)
      end

      desc "Attach staged audio files", hidden: true
      params do
        requires :signed_ids, type: Array[String]
      end
      post ":date/staged_audio", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        show.staged_audio.attach(params[:signed_ids])
        status 201
        { staged_audio: staged_audio_payload(show.reload) }
      end

      desc "Remove a staged audio file", hidden: true
      delete ":date/staged_audio/:attachment_id", requirements: { date: /\d{4}-\d{2}-\d{2}/ } do
        show = admin_show
        attachment = show.staged_audio_attachments.find(params[:attachment_id])
        blob_in_use = ActiveStorage::Attachment
                      .where(blob_id: attachment.blob_id)
                      .where.not(id: attachment.id)
                      .exists?
        blob_in_use ? attachment.destroy : attachment.purge
        { staged_audio: staged_audio_payload(show.reload) }
      end
    end
  end

  helpers do
    def admin_show
      Show.find_by!(date: params[:date])
    end

    def staged_audio_payload(show)
      show.staged_audio_attachments.includes(:blob).map do |attachment|
        {
          attachment_id: attachment.id,
          filename: Show.original_filename(attachment.blob),
          byte_size: attachment.blob.byte_size
        }
      end
    end

    def editor_payload(show)
      show_summary(show).merge(
        taper_notes: show.taper_notes,
        admin_notes: show.admin_notes,
        venue_id: show.venue_id,
        tour_id: show.tour_id,
        exclude_from_stats: show.performance_gap_value.zero?,
        performance_gap_value: show.performance_gap_value,
        matches_pnet: show.matches_pnet,
        staged_audio: staged_audio_payload(show),
        tracks: show.tracks.order(:position).map { |track| track_payload(track) }
      )
    end

    def track_payload(track)
      {
        id: track.id,
        position: track.position,
        set: track.set,
        title: track.title,
        slug: track.slug,
        duration: track.duration,
        audio_status: track.audio_status,
        jam_starts_at_second: track.jam_starts_at_second,
        exclude_from_stats: track.exclude_from_stats,
        songs: track.songs.map { |song| { id: song.id, title: song.title } },
        mp3_url: track.mp3_url,
        waveform_url: track.waveform_image_url
      }
    end

    def show_summary(show)
      {
        id: show.id,
        date: show.date.iso8601,
        venue_name: show.venue_name,
        published: show.published,
        audio_status: show.audio_status,
        tracks_count: show.tracks.count,
        duration: show.duration
      }
    end
  end
end
