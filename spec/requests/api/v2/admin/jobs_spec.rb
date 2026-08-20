require "rails_helper"

RSpec.describe "API v2 Admin Jobs" do
  let(:admin) { create(:user, :admin) }
  let(:admin_headers) { { "X-Auth-Token" => UserJwtService.call(admin) } }

  it "returns job state" do
    job = create(:admin_job, kind: "import", status: "running", progress: 40)
    get "/api/v2/admin/jobs/#{job.id}", headers: admin_headers
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("running")
    expect(body["progress"]).to eq(40)
  end

  it "requires admin" do
    job = create(:admin_job)
    get "/api/v2/admin/jobs/#{job.id}"
    expect(response).to have_http_status(:unauthorized)
  end

  describe "GET /api/v2/admin/jobs" do
    it "lists recent jobs newest first" do
      old = create(:admin_job, kind: "import", created_at: 2.days.ago)
      recent = create(:admin_job, kind: "publish")
      get "/api/v2/admin/jobs", headers: admin_headers
      ids = JSON.parse(response.body)["jobs"].map { |j| j["id"] }
      expect(ids.first).to eq(recent.id)
      expect(ids).to include(old.id)
    end

    it "honors the limit" do
      create_list(:admin_job, 3)
      get "/api/v2/admin/jobs", params: { limit: 2 }, headers: admin_headers
      expect(JSON.parse(response.body)["jobs"].size).to eq(2)
    end

    # The dashboard links a row to its show by date, so the date has to be in the
    # payload rather than only the id.
    it "includes the show date when the job has a show" do
      show = create(:show, date: "2024-07-19")
      create(:admin_job, kind: "publish", show:)
      get "/api/v2/admin/jobs", headers: admin_headers
      expect(JSON.parse(response.body)["jobs"].first["show_date"]).to eq("2024-07-19")
    end

    it "requires admin" do
      get "/api/v2/admin/jobs"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v2/admin/jobs/:id/audio" do
    let(:user) { create(:user) }
    let(:user_headers) { { "X-Auth-Token" => UserJwtService.call(user) } }
    let(:path) { Rails.root.join("tmp/spec/rendered.mp3").to_s }
    let(:job) do
      create(:admin_job, kind: "trim_preview", status: "done",
             payload: { "audio_paths" => [ path ] })
    end

    before do
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, "ID3fakemp3")
    end

    it "streams rendered audio" do
      get "/api/v2/admin/jobs/#{job.id}/audio", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("ID3fakemp3")
    end

    it "serves it as audio with a content length" do
      get "/api/v2/admin/jobs/#{job.id}/audio", headers: admin_headers
      expect(response.media_type).to eq("audio/mpeg")
      expect(response.headers["Content-Length"]).to eq("10")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/jobs/#{job.id}/audio"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/jobs/#{job.id}/audio", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "404s when the job rendered no audio" do
      bare = create(:admin_job, kind: "trim_preview", status: "done")
      get "/api/v2/admin/jobs/#{bare.id}/audio", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end

    it "404s when the rendered file is gone" do
      job
      File.delete(path)
      get "/api/v2/admin/jobs/#{job.id}/audio", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end

    it "404s for an index the job never rendered" do
      get "/api/v2/admin/jobs/#{job.id}/audio", params: { index: 3 }, headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # The whole point of preview-before-commit: what the job rendered must still be
  # auditionable through the endpoint once the job has finished and its temp
  # handles are gone.
  describe "streaming a completed trim preview" do
    let(:show) { create(:show, date: "2024-07-19") }
    let(:track) { create(:track, show:, position: 1, songs: [ create(:song) ]) }
    let(:source) { Rails.root.join("tmp/spec/audio_30s.mp3") }

    before do
      FileUtils.mkdir_p(source.dirname)
      unless File.exist?(source)
        system(
          "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
          "sine=frequency=440:duration=30", "-b:a", "128k", source.to_s,
          exception: true
        )
      end
      track.mp3_audio.attach(
        io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
      )
    end

    it "streams the render the job produced" do
      job = create(:admin_job, kind: "trim_preview", track:)
      opts = { trim_start: 0.0, trim_end: 20.0, fade_in: 0.2, fade_out: 6.0 }.to_json
      Admin::TrimJob.new.perform(track.id, job.id, opts, false)
      expect(job.reload.status).to eq("done")

      GC.start
      get "/api/v2/admin/jobs/#{job.id}/audio", headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("audio/mpeg")
      expect(response.body[0, 3]).to eq("ID3")
      expect(response.body.bytesize).to eq(File.size(job.payload["audio_paths"].first))
    end
  end

  # A boundary shift renders both sides, so each has to be auditionable through
  # the one endpoint by index before an admin commits to the move.
  describe "streaming a completed boundary preview" do
    let(:show) { create(:show, date: "2024-07-19") }
    let(:track) do
      create(:track, show:, position: 1, title: "Ghost", slug: "ghost")
    end
    let(:following) do
      create(:track, show:, position: 2, title: "Free", slug: "free")
    end
    let(:source) { Rails.root.join("tmp/spec/audio_60s.mp3") }

    before do
      FileUtils.mkdir_p(source.dirname)
      unless File.exist?(source)
        system(
          "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
          "sine=frequency=440:duration=60", "-b:a", "128k", source.to_s,
          exception: true
        )
      end
      [ track, following ].each do |record|
        record.mp3_audio.attach(
          io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
        )
        record.process_mp3_audio
      end
    end

    it "streams each half by index" do
      job = create(:admin_job, kind: "shift_boundary_preview", track:, show:)
      Admin::ShiftBoundaryJob.new.perform(track.id, job.id, 2.0, false)
      expect(job.reload.status).to eq("done")

      GC.start
      [ 0, 1 ].each do |index|
        get "/api/v2/admin/jobs/#{job.id}/audio",
            params: { index: }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("audio/mpeg")
        expect(response.body[0, 3]).to eq("ID3")
        expect(response.body.bytesize)
          .to eq(File.size(job.payload["audio_paths"][index]))
      end
    end

    it "serves different audio for each half" do
      job = create(:admin_job, kind: "shift_boundary_preview", track:, show:)
      Admin::ShiftBoundaryJob.new.perform(track.id, job.id, -2.0, false)

      get "/api/v2/admin/jobs/#{job.id}/audio", params: { index: 0 }, headers: admin_headers
      first = response.body
      get "/api/v2/admin/jobs/#{job.id}/audio", params: { index: 1 }, headers: admin_headers

      expect(response.body).not_to eq(first)
      expect(response.body.bytesize).to be > first.bytesize
    end
  end
end
