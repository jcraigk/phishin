# spec/requests/api/v2/admin/staging_spec.rb
require "rails_helper"

RSpec.describe "API v2 Admin Staging" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:admin_headers) { { "X-Auth-Token" => UserJwtService.call(admin) } }
  let!(:show) { create(:show, date: "2025-08-01", published: false, audio_status: "missing") }
  let(:base) { "/api/v2/admin/shows/2025-08-01" }
  let(:dir) { Admin::StagingDir.new(show) }
  let(:a) { create(:staged_track, show:, position: 1, title: "A", start_s: 0, end_s: 60) }
  let(:b) { create(:staged_track, show:, position: 2, title: "B", start_s: 60, end_s: 120) }

  def body = JSON.parse(response.body)

  def stage!
    create(:staged_source, show:, position: 1, filename: "a.flac", offset_s: 0, duration_s: 60)
    create(:staged_source, show:, position: 2, filename: "b.flac", offset_s: 60, duration_s: 60)
    [ a, b ]
  end

  describe "POST ingest" do
    it "requires admin" do
      post "#{base}/ingest", params: { archive_item: "x" }, headers: { "X-Auth-Token" => UserJwtService.call(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues the ingest job for an archive item" do
      expect { post "#{base}/ingest", params: { archive_item: "ph2025" }, headers: admin_headers }
        .to change(Admin::IngestStagingJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      job = AdminJob.find(body["job_id"])
      expect(job.kind).to eq("ingest")
      expect(Admin::IngestStagingJob.jobs.last["args"]).to eq([ show.id, job.id, [], "ph2025" ])
    end

    it "enqueues the ingest job for uploads" do
      post "#{base}/ingest", params: { signed_ids: [ "abc" ] }, headers: admin_headers
      expect(Admin::IngestStagingJob.jobs.last["args"]).to eq([ show.id, AdminJob.last.id, [ "abc" ], nil ])
    end

    it "422s without a source" do
      post "#{base}/ingest", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "422s when the show has tracks" do
      create(:track, show:, position: 1)
      post "#{base}/ingest", params: { archive_item: "x" }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET staging" do
    it "is null in the editor payload when nothing is staged" do
      get base, headers: admin_headers
      expect(body["staging"]).to be_nil
    end

    it "returns sources and tracks" do
      stage!
      get "#{base}/staging", headers: admin_headers
      expect(body["total_s"]).to eq(120.0)
      expect(body["sources"].map { it["filename"] }).to eq(%w[a.flac b.flac])
      expect(body["sources"].first["audio_url"]).to end_with("/staging/sources/#{show.staged_sources.first.id}/audio")
      expect(body["tracks"].map { it["title"] }).to eq(%w[A B])
      expect(body["tracks"].first).to include("start_s" => 0.0, "end_s" => 60.0, "fade_in_s" => 0.0)
    end
  end

  describe "PATCH track" do
    before { stage! }

    it "updates metadata and fades" do
      song = create(:song, title: "Ghost")
      patch "#{base}/staging/tracks/#{a.id}", params: { title: "Ghost", set: "2", song_id: song.id, fade_out_s: 3 }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(a.reload).to have_attributes(title: "Ghost", set: "2", song_id: song.id, fade_out_s: 3.0)
    end

    it "moves an edge inside the free space around it" do
      patch "#{base}/staging/tracks/#{a.id}", params: { start_s: 2.5 }, headers: admin_headers
      expect(a.reload.start_s.to_f).to eq(2.5)
    end

    it "refuses an edge that overlaps a neighbor" do
      patch "#{base}/staging/tracks/#{a.id}", params: { end_s: 61 }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["message"]).to include('overlap')
    end

    it "refuses an edge past the timeline" do
      patch "#{base}/staging/tracks/#{b.id}", params: { end_s: 121 }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "clears the song with a null id" do
      a.update!(song: create(:song))
      patch "#{base}/staging/tracks/#{a.id}", params: { song_id: nil }.to_json,
            headers: admin_headers.merge("Content-Type" => "application/json")
      expect(a.reload.song).to be_nil
    end
  end

  describe "POST split" do
    before { stage! }

    it "cuts a track in two at the given time and renumbers" do
      post "#{base}/staging/tracks/#{a.id}/split", params: { at_s: 20 }, headers: admin_headers
      tracks = show.staged_tracks.ordered
      expect(tracks.map { [ it.position, it.start_s.to_f, it.end_s.to_f ] })
        .to eq([ [ 1, 0.0, 20.0 ], [ 2, 20.0, 60.0 ], [ 3, 60.0, 120.0 ] ])
      expect(tracks.second.title).to eq("A (2)")
      expect(tracks.second.set).to eq("1")
    end

    # A fade-out belongs to the end of the track; after a split that end is the
    # second half's. The first half keeps the fade-in.
    it "hands the fade-out to the second half" do
      a.update!(fade_in_s: 1, fade_out_s: 4)
      post "#{base}/staging/tracks/#{a.id}/split", params: { at_s: 20 }, headers: admin_headers
      first, second = show.staged_tracks.ordered.first(2)
      expect([ first.fade_in_s, first.fade_out_s ].map(&:to_f)).to eq([ 1.0, 0.0 ])
      expect([ second.fade_in_s, second.fade_out_s ].map(&:to_f)).to eq([ 0.0, 4.0 ])
    end

    it "refuses a cut that leaves a side too short" do
      post "#{base}/staging/tracks/#{a.id}/split", params: { at_s: 59.5 }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST combine" do
    before { stage! }

    it "merges a track with the one below it" do
      b.update!(fade_out_s: 2)
      post "#{base}/staging/tracks/#{a.id}/combine", headers: admin_headers
      tracks = show.staged_tracks.ordered
      expect(tracks.size).to eq(1)
      expect(tracks.first).to have_attributes(title: "A", position: 1)
      expect([ tracks.first.start_s, tracks.first.end_s, tracks.first.fade_out_s ].map(&:to_f)).to eq([ 0.0, 120.0, 2.0 ])
    end

    it "422s on the last track" do
      post "#{base}/staging/tracks/#{b.id}/combine", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PUT boundary" do
    before { stage! }

    it "moves the seam between a track and the next" do
      put "#{base}/staging/tracks/#{a.id}/boundary", params: { at_s: 63.25 }, headers: admin_headers
      expect(a.reload.end_s.to_f).to eq(63.25)
      expect(b.reload.start_s.to_f).to eq(63.25)
    end

    it "refuses a seam that leaves either side too short" do
      put "#{base}/staging/tracks/#{a.id}/boundary", params: { at_s: 119.5 }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE track" do
    before { stage! }

    it "removes the track and renumbers" do
      delete "#{base}/staging/tracks/#{a.id}", headers: admin_headers
      expect(show.staged_tracks.ordered.map { [ it.position, it.title ] }).to eq([ [ 1, "B" ] ])
    end
  end

  describe "GET source audio" do
    before do
      stage!
      dir.reset!
      File.binwrite(dir.proxy_path(show.staged_sources.first), "\xFF\xFBproxy".b)
    end

    after { dir.remove! }

    it "streams the proxy" do
      get "#{base}/staging/sources/#{show.staged_sources.first.id}/audio", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("audio/mpeg")
      expect(response.body).to eq("\xFF\xFBproxy".b)
    end

    it "404s when the proxy is missing" do
      get "#{base}/staging/sources/#{show.staged_sources.last.id}/audio", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST commit" do
    it "enqueues the commit job" do
      stage!
      expect { post "#{base}/staging/commit", headers: admin_headers }
        .to change(Admin::CommitStagingJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("commit_staging")
    end

    it "422s with nothing staged" do
      post "#{base}/staging/commit", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE staging" do
    it "drops the rows and the directory" do
      stage!
      dir.reset!
      delete "#{base}/staging", headers: admin_headers
      expect(response).to have_http_status(:no_content)
      expect(show.reload.staging?).to be(false)
      expect(show.staged_tracks).to be_empty
      expect(Dir.exist?(dir.root)).to be(false)
    end
  end
end
