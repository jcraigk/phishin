require "rails_helper"

RSpec.describe "API v2 Admin Shows" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    { "X-Auth-Token" => token_for(admin) }
  end

  # Destroying a record with attachments enqueues ActiveStorage::PurgeJob rather than
  # purging inline, so blob deletion is invisible to a test unless the job is run.
  # Only purge jobs are drained; draining everything would fire unrelated jobs.
  def run_enqueued_purge_jobs
    Sidekiq::Queues.jobs_by_queue.values.flatten.each do |job|
      next unless job["wrapped"] == "ActiveStorage::PurgeJob"
      ActiveJob::Base.execute(job["args"].first)
    end
  end

  describe "GET /api/v2/admin/shows" do
    before do
      create(:show, date: "2024-06-01", published: false)
      create(:show, date: "2024-06-02")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/shows"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/shows", headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "lists draft shows for an admin" do
      get "/api/v2/admin/shows", params: { published: false }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      dates = JSON.parse(response.body)["shows"].map { |s| s["date"] }
      expect(dates).to eq([ "2024-06-01" ])
    end

    it "lists all shows without the filter" do
      get "/api/v2/admin/shows", headers: admin_headers
      expect(JSON.parse(response.body)["shows"].size).to eq(2)
    end
  end

  describe "POST /api/v2/admin/shows" do
    it "returns 401 without a token" do
      post "/api/v2/admin/shows", params: { date: "2025-08-01" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/shows",
           params: { date: "2025-08-01" },
           headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a draft show" do
      post "/api/v2/admin/shows", params: { date: "2025-08-01" }, headers: admin_headers
      expect(response).to have_http_status(:created)
      show = Show.find_by(date: "2025-08-01")
      expect(show.published).to be(false)
      expect(show.audio_status).to eq("missing")
    end

    it "409s when the date exists" do
      create(:show, date: "2025-08-01")
      post "/api/v2/admin/shows", params: { date: "2025-08-01" }, headers: admin_headers
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "staged audio" do
    let!(:show) { create(:show, date: "2025-08-01", published: false) }

    def upload_blob(filename)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake mp3 bytes"),
        filename:,
        content_type: "audio/mpeg"
      )
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/shows/2025-08-01/staged_audio",
           params: { signed_ids: [] }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/shows/2025-08-01/staged_audio",
           params: { signed_ids: [] }.to_json,
           headers: {
             "X-Auth-Token" => token_for(user),
             "CONTENT_TYPE" => "application/json"
           }
      expect(response).to have_http_status(:forbidden)
    end

    it "attaches staged files by signed id" do
      blob = upload_blob("I 01 Tweezer.mp3")
      post "/api/v2/admin/shows/2025-08-01/staged_audio",
           params: { signed_ids: [ blob.signed_id ] }.to_json,
           headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      expect(response).to have_http_status(:created)
      expect(show.reload.staged_audio.map { |a| a.filename.to_s }).to eq([ "I 01 Tweezer.mp3" ])
    end

    it "returns the staged file list with original filenames" do
      blob = upload_blob("II 03 Harry Hood.mp3")
      post "/api/v2/admin/shows/2025-08-01/staged_audio",
           params: { signed_ids: [ blob.signed_id ] }.to_json,
           headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      staged = JSON.parse(response.body)["staged_audio"]
      expect(staged.map { |f| f["filename"] }).to eq([ "II 03 Harry Hood.mp3" ])
      expect(staged.first["byte_size"]).to eq(blob.byte_size)
    end

    # ActiveStorage::Filename#to_s replaces ">" with "-". Segue markers must
    # survive for the importer to match track titles in Task 4.
    it "preserves segue characters in the staged filename payload" do
      blob = upload_blob("II 03 Harry Hood > Wilson.mp3")
      post "/api/v2/admin/shows/2025-08-01/staged_audio",
           params: { signed_ids: [ blob.signed_id ] }.to_json,
           headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      staged = JSON.parse(response.body)["staged_audio"]
      expect(staged.map { |f| f["filename"] }).to eq([ "II 03 Harry Hood > Wilson.mp3" ])
      expect(show.reload.staged_audio_filenames).to eq([ "II 03 Harry Hood > Wilson.mp3" ])
    end

    it "detaches a staged file" do
      show.staged_audio.attach(upload_blob("x.mp3"))
      attachment_id = show.staged_audio_attachments.first.id
      delete "/api/v2/admin/shows/2025-08-01/staged_audio/#{attachment_id}",
             headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(show.reload.staged_audio.count).to eq(0)
    end

    it "keeps the blob when a track still uses it" do
      blob = upload_blob("shared.mp3")
      show.staged_audio.attach(blob)
      track = create(:track, show:)
      track.mp3_audio.attach(blob)
      attachment_id = show.staged_audio_attachments.first.id

      delete "/api/v2/admin/shows/2025-08-01/staged_audio/#{attachment_id}",
             headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(show.reload.staged_audio.count).to eq(0)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(track.reload.mp3_audio.attached?).to be(true)
    end
  end

  describe "GET /api/v2/admin/shows/:date" do
    it "returns 401 without a token" do
      create(:show, date: "2025-08-01", published: false)
      get "/api/v2/admin/shows/2025-08-01"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      create(:show, date: "2025-08-01", published: false)
      get "/api/v2/admin/shows/2025-08-01", headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns the editor payload for a draft" do
      create(:show, date: "2025-08-01", published: false)
      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      body = JSON.parse(response.body)
      expect(body["date"]).to eq("2025-08-01")
      expect(body["published"]).to be(false)
      expect(body["tracks"]).to eq([])
      expect(body["staged_audio"]).to eq([])
    end

    it "includes tracks for a show with audio" do
      show = create(:show, date: "2025-08-02")
      track = create(:track, show:, position: 1, set: "1")
      get "/api/v2/admin/shows/2025-08-02", headers: admin_headers
      body = JSON.parse(response.body)
      expect(body["tracks"].map { |t| t["id"] }).to eq([ track.id ])
      expect(body["tracks"].first["title"]).to eq(track.title)
    end

    it "404s for an unknown date" do
      get "/api/v2/admin/shows/1980-01-01", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v2/admin/shows/:date/import" do
    let!(:show) { create(:show, date: "2025-08-01", published: false, audio_status: "missing") }

    it "returns 401 without a token" do
      post "/api/v2/admin/shows/2025-08-01/import"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/shows/2025-08-01/import",
           headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues the import job" do
      expect {
        post "/api/v2/admin/shows/2025-08-01/import", headers: admin_headers
      }.to change(Admin::ImportShowJob.jobs, :size).by(1)

      expect(response).to have_http_status(:created)
      job_id = JSON.parse(response.body)["job_id"]
      job = AdminJob.find(job_id)
      expect(job.kind).to eq("import")
      expect(job.show).to eq(show)
      expect(Admin::ImportShowJob.jobs.last["args"]).to eq([ show.id, job.id ])
    end

    it "422s for a published show" do
      show.update!(published: true)
      expect {
        post "/api/v2/admin/shows/2025-08-01/import", headers: admin_headers
      }.not_to change(Admin::ImportShowJob.jobs, :size)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "422s when the show already has tracks" do
      create(:track, show:, position: 1)
      expect {
        post "/api/v2/admin/shows/2025-08-01/import", headers: admin_headers
      }.not_to change(Admin::ImportShowJob.jobs, :size)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s for an unknown date" do
      post "/api/v2/admin/shows/1980-01-01/import", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v2/admin/shows/:date" do
    let!(:show) { create(:show, date: "2025-08-01", published: false) }
    let(:venue) { create(:venue) }

    def patch_show(params, headers = admin_headers)
      patch "/api/v2/admin/shows/2025-08-01",
            params: params.to_json,
            headers: headers.merge("CONTENT_TYPE" => "application/json")
    end

    it "returns 401 without a token" do
      patch_show({ taper_notes: "x" }, {})
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      patch_show({ taper_notes: "x" }, { "X-Auth-Token" => token_for(user) })
      expect(response).to have_http_status(:forbidden)
    end

    it "updates provided fields only" do
      show.update!(admin_notes: "keep me")
      patch_show(taper_notes: "AUD > FLAC", venue_id: venue.id)
      expect(response).to have_http_status(:ok)
      show.reload
      expect(show.taper_notes).to eq("AUD > FLAC")
      expect(show.venue).to eq(venue)
      expect(show.admin_notes).to eq("keep me")
    end

    it "returns the editor payload" do
      patch_show(admin_notes: "checked")
      body = JSON.parse(response.body)
      expect(body["date"]).to eq("2025-08-01")
      expect(body["admin_notes"]).to eq("checked")
      expect(body["tracks"]).to eq([])
    end

    it "updates the remaining editable attributes" do
      tour = create(:tour)
      patch_show(
        tour_id: tour.id,
        performance_gap_value: 0,
        matches_pnet: false
      )
      expect(response).to have_http_status(:ok)
      show.reload
      expect(show.tour).to eq(tour)
      expect(show.performance_gap_value).to eq(0)
      expect(show.matches_pnet).to be(false)
      expect(JSON.parse(response.body)["exclude_from_stats"]).to be(true)
    end

    it "clears the venue on a draft" do
      show.update!(venue:)
      patch_show(venue_id: nil)
      expect(response).to have_http_status(:ok)
      expect(show.reload.venue).to be_nil
    end

    it "rejects unknown venue ids" do
      expect { patch_show(venue_id: 999_999) }.not_to change { show.reload.venue_id }
      expect(response).to have_http_status(:not_found)
    end

    it "rejects unknown tour ids" do
      patch_show(tour_id: 999_999)
      expect(response).to have_http_status(:not_found)
    end

    it "422s when clearing the venue of a published show" do
      published = create(:show, date: "2025-09-01", published: true)
      patch "/api/v2/admin/shows/2025-09-01",
            params: { venue_id: nil }.to_json,
            headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      expect(response).to have_http_status(:unprocessable_content)
      expect(published.reload.venue).to be_present
    end

    it "422s when clearing the tour of a published show" do
      published = create(:show, date: "2025-09-01", published: true)
      patch "/api/v2/admin/shows/2025-09-01",
            params: { tour_id: nil }.to_json,
            headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      expect(response).to have_http_status(:unprocessable_content)
      expect(published.reload.tour).to be_present
    end

    it "404s for an unknown date" do
      patch "/api/v2/admin/shows/1980-01-01",
            params: { taper_notes: "x" }.to_json,
            headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v2/admin/shows/:date" do
    it "returns 401 without a token" do
      create(:show, date: "2025-08-01", published: false)
      delete "/api/v2/admin/shows/2025-08-01"
      expect(response).to have_http_status(:unauthorized)
      expect(Show.exists?(date: "2025-08-01")).to be(true)
    end

    it "returns 403 for a non-admin user" do
      create(:show, date: "2025-08-01", published: false)
      delete "/api/v2/admin/shows/2025-08-01", headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
      expect(Show.exists?(date: "2025-08-01")).to be(true)
    end

    it "destroys the show and its tracks" do
      show = create(:show, date: "2025-08-01", published: false)
      create(:track, show:, position: 1, songs: [ create(:song) ])
      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(response).to have_http_status(:no_content)
      expect(Show.exists?(date: "2025-08-01")).to be(false)
      expect(Track.where(show_id: show.id)).to be_empty
    end

    it "destroys a draft with no venue or tour" do
      show = create(:show, date: "2025-08-01", published: false, venue: nil, tour: nil)
      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(response).to have_http_status(:no_content)
      expect(Show.exists?(show.id)).to be(false)
    end

    it "destroys a published show with a venue, tour and tracks" do
      show = create(:show, date: "2025-08-01", published: true)
      venue = show.venue
      tour = show.tour
      create(:track, show:, position: 1, songs: [ create(:song) ])

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers

      expect(response).to have_http_status(:no_content)
      expect(Show.exists?(show.id)).to be(false)
      expect(Venue.exists?(venue.id)).to be(true)
      expect(Tour.exists?(tour.id)).to be(true)
    end

    it "destroys dependent likes and tags" do
      show = create(:show, date: "2025-08-01", published: false)
      like = create(:like, likable: show, user:)
      show_tag = create(:show_tag, show:, tag: create(:tag))
      track = create(:track, show:, position: 1)
      track_like = create(:like, likable: track, user:)

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers

      expect(response).to have_http_status(:no_content)
      expect(Like.exists?(like.id)).to be(false)
      expect(Like.exists?(track_like.id)).to be(false)
      expect(ShowTag.exists?(show_tag.id)).to be(false)
      expect(SongsTrack.where(track_id: track.id)).to be_empty
    end

    it "removes staged audio attachments" do
      show = create(:show, date: "2025-08-01", published: false)
      show.staged_audio.attach(
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("fake mp3 bytes"),
          filename: "I 01 Tweezer.mp3",
          content_type: "audio/mpeg"
        )
      )

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers

      expect(response).to have_http_status(:no_content)
      expect(ActiveStorage::Attachment.where(record_type: "Show", record_id: show.id)).to be_empty
    end

    # Deleting a show enqueues a purge for each of its blobs. These two examples pin
    # down that a blob survives while anything else still points at it, and is only
    # then reclaimed. Purge jobs must actually run or the assertions prove nothing.
    it "keeps a blob that a track on another show still references" do
      show = create(:show, date: "2025-08-01", published: false)
      keeper = create(:show, date: "2025-08-05", published: false)
      track = create(:track, show: keeper, position: 1)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake mp3 bytes"),
        filename: "copied.mp3",
        content_type: "audio/mpeg"
      )
      show.staged_audio.attach(blob)
      track.mp3_audio.attach(blob)

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      run_enqueued_purge_jobs

      expect(response).to have_http_status(:no_content)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(blob.service.exist?(blob.key)).to be(true)
      expect(track.reload.mp3_audio.attached?).to be(true)
    end

    it "keeps a blob that another record still references" do
      show = create(:show, date: "2025-08-01", published: false)
      other_show = create(:show, date: "2025-08-02", published: false)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake mp3 bytes"),
        filename: "shared.mp3",
        content_type: "audio/mpeg"
      )
      show.staged_audio.attach(blob)
      other_show.staged_audio.attach(blob)

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      run_enqueued_purge_jobs

      expect(response).to have_http_status(:no_content)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(other_show.reload.staged_audio.count).to eq(1)
      expect(blob.service.exist?(blob.key)).to be(true)
    end

    # The same guard must not leak blobs that nothing else points at.
    it "purges a blob no other record references" do
      show = create(:show, date: "2025-08-01", published: false)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake mp3 bytes"),
        filename: "exclusive.mp3",
        content_type: "audio/mpeg"
      )
      show.staged_audio.attach(blob)

      delete "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      run_enqueued_purge_jobs

      expect(response).to have_http_status(:no_content)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    end

    it "404s for an unknown date" do
      delete "/api/v2/admin/shows/1980-01-01", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
