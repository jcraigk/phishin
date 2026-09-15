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

  describe "GET staging" do
    it "is null in the editor payload when nothing is staged" do
      get base, headers: admin_headers
      expect(body["staging"]).to be_nil
    end

    it "returns sources and tracks in the editor payload" do
      stage!
      get base, headers: admin_headers
      staging = body["staging"]
      expect(staging["total_s"]).to eq(120.0)
      expect(staging["sources"].map { it["filename"] }).to eq(%w[a.flac b.flac])
      expect(staging["sources"].first["audio_url"]).to end_with("/staging/sources/#{show.staged_sources.first.id}/audio")
      expect(staging["tracks"].map { it["title"] }).to eq(%w[A B])
      expect(staging["tracks"].first).to include("start_s" => 0.0, "end_s" => 60.0, "fade_in_s" => 0.0)
    end
  end

  describe "PATCH track" do
    before { stage! }

    it "updates metadata and fades" do
      song = create(:song, title: "Ghost")
      patch "#{base}/staging/tracks/#{b.id}", params: { title: "Ghost", set: "2", song_ids: [ song.id ], fade_out_s: 3 }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(b.reload).to have_attributes(title: "Ghost", set: "2", song_ids: [ song.id ], fade_out_s: 3.0)
    end

    it "refuses a set change that puts sets out of order" do
      patch "#{base}/staging/tracks/#{a.id}", params: { set: "2" }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["message"]).to include("order")
      expect(a.reload.set).to eq("1")
    end

    it "fades the edges of a new set break and clears them again when it closes" do
      patch "#{base}/staging/tracks/#{b.id}", params: { set: "2" }, headers: admin_headers
      expect(a.reload.fade_out_s.to_f).to eq(6.0)
      expect(b.reload.fade_in_s.to_f).to eq(0.2)

      patch "#{base}/staging/tracks/#{b.id}", params: { set: "1" }, headers: admin_headers
      expect(a.reload.fade_out_s.to_f).to eq(0)
      expect(b.reload.fade_in_s.to_f).to eq(0)
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

    it "clears the songs with an empty list" do
      a.update!(song_ids: [ create(:song).id ])
      patch "#{base}/staging/tracks/#{a.id}", params: { song_ids: [] }.to_json,
            headers: admin_headers.merge("Content-Type" => "application/json")
      expect(a.reload.song_ids).to eq([])
    end

    it "still refuses moving a track's start past a neighbor" do
      patch "#{base}/staging/tracks/#{b.id}", params: { start_s: 55 }, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(a.reload.position).to eq(1)
      expect(b.reload.position).to eq(2)
    end

    it "leaves positions unchanged when start_s moves within its own gap" do
      patch "#{base}/staging/tracks/#{a.id}", params: { start_s: 5 }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(a.reload.position).to eq(1)
      expect(b.reload.position).to eq(2)
    end

    it "renumbers by start_s order after a start_s edit" do
      patch "#{base}/staging/tracks/#{a.id}", params: { start_s: 5 }, headers: admin_headers
      tracks = show.staged_tracks.ordered.to_a
      expect(tracks.map { [ it.position, it.start_s.to_f ] }).to eq([ [ 1, 5.0 ], [ 2, 60.0 ] ])
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

    it "merges a track with the one below it, joining titles and songs" do
      ghost, mikes = create(:song, title: "Ghost"), create(:song, title: "Mike's Song")
      a.update!(song_ids: [ ghost.id ])
      b.update!(fade_out_s: 2, song_ids: [ mikes.id ])
      post "#{base}/staging/tracks/#{a.id}/combine", headers: admin_headers
      tracks = show.staged_tracks.ordered
      expect(tracks.size).to eq(1)
      expect(tracks.first).to have_attributes(title: "A > B", position: 1, song_ids: [ ghost.id, mikes.id ])
      expect([ tracks.first.start_s, tracks.first.end_s, tracks.first.fade_out_s ].map(&:to_f)).to eq([ 0.0, 120.0, 2.0 ])
    end

    it "422s on the last track" do
      post "#{base}/staging/tracks/#{b.id}/combine", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST uncombine" do
    before { stage! }

    it "restores the two tracks, keeping the current end and fade on the second" do
      ghost, mikes = create(:song, title: "Ghost"), create(:song, title: "Mike's Song")
      a.update!(song_ids: [ ghost.id ])
      b.update!(song_ids: [ mikes.id ])
      post "#{base}/staging/tracks/#{a.id}/combine", headers: admin_headers
      merged = show.staged_tracks.ordered.first
      expect(body["tracks"].first["undo_combine"]).to eq("B")
      merged.update!(end_s: 110, fade_out_s: 4)

      post "#{base}/staging/tracks/#{merged.id}/uncombine", headers: admin_headers
      tracks = show.staged_tracks.ordered
      expect(tracks.map { [ it.position, it.title, it.song_ids, it.start_s.to_f, it.end_s.to_f, it.fade_out_s.to_f ] })
        .to eq([ [ 1, "A", [ ghost.id ], 0.0, 60.0, 0.0 ], [ 2, "B", [ mikes.id ], 60.0, 110.0, 4.0 ] ])
      expect(body["tracks"].first["undo_combine"]).to be_nil
    end

    it "422s when nothing was combined" do
      post "#{base}/staging/tracks/#{a.id}/uncombine", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "422s when the old seam no longer falls inside the track" do
      post "#{base}/staging/tracks/#{a.id}/combine", headers: admin_headers
      merged = show.staged_tracks.ordered.first
      merged.update!(start_s: 100)
      post "#{base}/staging/tracks/#{merged.id}/uncombine", headers: admin_headers
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

  describe "GET peaks" do
    before do
      stage!
      dir.reset!
    end

    after { dir.remove! }

    it "serves the peak bytes and advertises them in the staging payload" do
      File.binwrite(dir.peaks, [ 0, 128, 255 ].pack("C*"))

      get base, headers: admin_headers
      expect(body["staging"]["peaks_url"]).to end_with("/staging/peaks")
      expect(body["staging"]["peaks_rate"]).to eq(Admin::StagingPeaks::RATE)

      get "#{base}/staging/peaks", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Peaks-Rate"]).to eq(Admin::StagingPeaks::RATE.to_s)
      expect(response.body.bytes).to eq([ 0, 128, 255 ])
    end

    it "404s and reports no url before peaks exist" do
      get base, headers: admin_headers
      expect(body["staging"]["peaks_url"]).to be_nil

      get "#{base}/staging/peaks", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST commit" do
    def ready!
      stage!
      song = create(:song)
      show.staged_tracks.update_all(song_ids: [ song.id ])
    end

    it "enqueues the commit job" do
      ready!
      expect { post "#{base}/staging/commit", headers: admin_headers }
        .to change(Admin::CommitStagingJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("commit_staging")
    end

    it "reports the running commit in the staging payload" do
      ready!
      post "#{base}/staging/commit", headers: admin_headers
      get base, headers: admin_headers
      expect(body["staging"]["commit_job_id"]).to eq(AdminJob.last.id)
    end

    it "422s without a venue" do
      ready!
      show.update!(venue: nil)
      post "#{base}/staging/commit", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["message"]).to include("venue")
    end

    it "422s when a track has no song" do
      ready!
      b.update_columns(song_ids: [])
      post "#{base}/staging/commit", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["message"]).to include("B")
    end

    it "422s with nothing staged" do
      post "#{base}/staging/commit", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "422s for a published show" do
      stage!
      show.update!(venue: create(:venue), tour: create(:tour), published: true)
      post "#{base}/staging/commit", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["message"]).to include("already published")
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

    it "removes tracks left by a failed commit" do
      stage!
      dir.reset!
      create(:track, show:, position: 1, title: "Leftover")
      delete "#{base}/staging", headers: admin_headers
      expect(response).to have_http_status(:no_content)
      expect(show.reload.tracks).to be_empty
    end
  end
end
