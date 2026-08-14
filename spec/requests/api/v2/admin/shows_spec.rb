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
end
