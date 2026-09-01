require "rails_helper"

RSpec.describe "API v2 Admin Tracks" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:show) { create(:show, date: "2025-08-01", published: false) }
  let!(:song_a) { create(:song, title: "Ghost") }
  let!(:song_b) { create(:song, title: "Free") }
  let!(:track1) { create(:track, show:, position: 1, title: "Ghost", set: "1", songs: [ song_a ]) }
  let!(:track2) { create(:track, show:, position: 2, title: "Free", set: "1", songs: [ song_b ]) }
  let!(:track3) { create(:track, show:, position: 3, title: "Banter", set: "1", songs: [ song_a ]) }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    {
      "X-Auth-Token" => token_for(admin),
      "CONTENT_TYPE" => "application/json"
    }
  end

  def user_headers
    { "X-Auth-Token" => token_for(user), "CONTENT_TYPE" => "application/json" }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  def positions_for(show)
    show.tracks.reload.order(:position).pluck(:position)
  end

  describe "PATCH /api/v2/admin/tracks/:id" do
    it "returns 401 without a token" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Nope" }.to_json,
            headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Nope" }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "updates the slug directly" do
      patch "/api/v2/admin/tracks/#{track1.id}", params: { slug: "custom-slug" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(track1.reload.slug).to eq("custom-slug")
    end

    it "rejects a slug with invalid characters" do
      patch "/api/v2/admin/tracks/#{track1.id}", params: { slug: "Bad Slug!" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "updates title, set, and songs" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Ghost Jam", set: "2", song_ids: [ song_b.id ] }.to_json,
            headers: admin_headers
      expect(response).to have_http_status(:ok)
      track1.reload
      expect(track1.title).to eq("Ghost Jam")
      expect(track1.set).to eq("2")
      expect(track1.songs).to eq([ song_b ])
    end

    it "returns the track payload" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Ghost Jam" }.to_json, headers: admin_headers
      expect(json).to include(id: track1.id, position: 1, title: "Ghost Jam")
    end

    it "regenerates the slug on a draft show" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Ghost Jam" }.to_json, headers: admin_headers
      expect(track1.reload.slug).to eq("ghost-jam")
    end

    it "preserves the slug on a published show" do
      show.update!(published: true)
      original_slug = track1.slug
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { title: "Ghost Jam" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:ok)
      track1.reload
      expect(track1.title).to eq("Ghost Jam")
      expect(track1.slug).to eq(original_slug)
    end

    it "updates jam_starts_at_second and exclude_from_stats" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { jam_starts_at_second: 120, exclude_from_stats: true }.to_json,
            headers: admin_headers
      track1.reload
      expect(track1.jam_starts_at_second).to eq(120)
      expect(track1.exclude_from_stats).to be(true)
    end

    it "clears jam_starts_at_second when passed null" do
      track1.update!(jam_starts_at_second: 90)
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { jam_starts_at_second: nil }.to_json, headers: admin_headers
      expect(track1.reload.jam_starts_at_second).to be_nil
    end

    it "rejects invalid sets" do
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { set: "9" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "404s for an unknown track" do
      patch "/api/v2/admin/tracks/0",
            params: { title: "Nope" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end

    it "422s when clearing songs on a published show" do
      show.update!(published: true)
      patch "/api/v2/admin/tracks/#{track1.id}",
            params: { song_ids: [] }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PUT /api/v2/admin/shows/:date/track_order" do
    it "returns 401 without a token" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track1.id ] }.to_json,
          headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track1.id ] }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "reorders tracks" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track3.id, track1.id, track2.id ] }.to_json,
          headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(track3.reload.position).to eq(1)
      expect(track1.reload.position).to eq(2)
      expect(track2.reload.position).to eq(3)
    end

    it "moves the first track to last across five tracks without colliding" do
      track4 = create(:track, show:, position: 4, title: "Fourth", set: "1")
      track5 = create(:track, show:, position: 5, title: "Fifth", set: "1")
      order = [ track2, track3, track4, track5, track1 ]

      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: order.map(&:id) }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(order.map { |t| t.reload.position }).to eq([ 1, 2, 3, 4, 5 ])
      expect(positions_for(show)).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "moves the last track to first without colliding" do
      track4 = create(:track, show:, position: 4, title: "Fourth", set: "1")
      track5 = create(:track, show:, position: 5, title: "Fifth", set: "1")
      order = [ track5, track1, track2, track3, track4 ]

      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: order.map(&:id) }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(order.map { |t| t.reload.position }).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "returns tracks in the new order in the editor payload" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track3.id, track1.id, track2.id ] }.to_json,
          headers: admin_headers
      expect(json[:tracks].map { |t| t[:id] }).to eq([ track3.id, track1.id, track2.id ])
    end

    it "applies set changes for moved tracks in the same request" do
      track4 = create(:track, show:, position: 4, title: "Fourth", set: "2")
      order = [ track1, track2, track4, track3 ]

      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: order.map(&:id), sets: { track4.id.to_s => "1" } }.to_json,
          headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(order.map { |t| t.reload.position }).to eq([ 1, 2, 3, 4 ])
      expect(track4.set).to eq("1")
      expect(json[:tracks].find { |t| t[:id] == track4.id }[:set]).to eq("1")
    end

    it "rejects an invalid set" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track3.id, track1.id, track2.id ], sets: { track3.id.to_s => "Q" } }.to_json,
          headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(positions_for(show)).to eq([ 1, 2, 3 ])
      expect(track3.reload.set).to eq("1")
    end

    it "rejects a partial list" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track1.id ] }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(positions_for(show)).to eq([ 1, 2, 3 ])
    end

    it "rejects a list containing a track from another show" do
      other = create(:track, position: 1, set: "1")
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track1.id, track2.id, other.id ] }.to_json,
          headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(track1.reload.position).to eq(1)
    end

    it "rejects a list with duplicate ids" do
      put "/api/v2/admin/shows/2025-08-01/track_order",
          params: { track_ids: [ track1.id, track1.id, track2.id ] }.to_json,
          headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v2/admin/tracks/:id/shift_boundary_preview and _apply" do
    def tone
      path = Rails.root.join("tmp/spec/boundary_request_tone.mp3")
      FileUtils.mkdir_p(path.dirname)
      unless File.exist?(path)
        system(
          "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
          "sine=frequency=440:duration=2", "-b:a", "128k", path.to_s, exception: true
        )
      end
      path
    end

    def attach_audio(track, duration_ms)
      track.mp3_audio.attach(
        io: File.open(tone), filename: "audio.mp3", content_type: "audio/mpeg"
      )
      track.update_columns(duration: duration_ms)
    end

    let(:body) { { delta_s: 2.0 }.to_json }

    before do
      attach_audio(track1, 10_000)
      attach_audio(track2, 6_000)
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without a token on apply" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user on apply" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "changes no audio when an unauthenticated apply is rejected" do
      keys = [ track1.mp3_audio.blob.key, track2.mp3_audio.blob.key ]
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: { "CONTENT_TYPE" => "application/json" }
      expect([ track1.reload.mp3_audio.blob.key, track2.reload.mp3_audio.blob.key ])
        .to eq(keys)
    end

    it "changes no audio when a non-admin apply is rejected" do
      keys = [ track1.mp3_audio.blob.key, track2.mp3_audio.blob.key ]
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: user_headers
      expect([ track1.reload.mp3_audio.blob.key, track2.reload.mp3_audio.blob.key ])
        .to eq(keys)
    end

    it "does not enqueue a job for an unauthorized apply" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
             params: body, headers: user_headers
      }.not_to change(Admin::ShiftBoundaryJob.jobs, :size)
    end

    it "returns a job id for a preview" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the preview without applying" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"])
        .to eq([ track1.id, AdminJob.last.id, 2.0, false, nil ])
    end

    it "records the preview job kind" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(AdminJob.last)
        .to have_attributes(kind: "shift_boundary_preview", track_id: track1.id)
    end

    it "enqueues the apply with the apply flag set" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"])
        .to eq([ track1.id, AdminJob.last.id, 2.0, true, nil ])
    end

    it "passes a negative delta through unchanged" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: -2.0 }.to_json, headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"].third).to eq(-2.0)
    end

    it "422s on a delta past the end of the second track" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 8.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "names the allowed range when the delta is too large" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 8.0 }.to_json, headers: admin_headers
      expect(json[:message]).to eq("Boundary shift must be between -9.0s and 5.0s")
    end

    it "422s on a delta past the start of the first track" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: -12.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "names the allowed range when the delta is too negative" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: -12.0 }.to_json, headers: admin_headers
      expect(json[:message]).to eq("Boundary shift must be between -9.0s and 5.0s")
    end

    it "enqueues nothing for an out-of-range delta" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
             params: { delta_s: 8.0 }.to_json, headers: admin_headers
      }.not_to change(Admin::ShiftBoundaryJob.jobs, :size)
    end

    it "422s on the last track of the show" do
      post "/api/v2/admin/tracks/#{track3.id}/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "passes both titles through to the job" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer", second: "Mike's Song" } }.to_json,
           headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"].last)
        .to eq({ "first" => "Tweezer", "second" => "Mike's Song" })
    end

    it "passes a single side through to the job" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { second: "Tweezer" } }.to_json,
           headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"].last)
        .to eq({ "second" => "Tweezer" })
    end

    it "trims whitespace off a title" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "  Tweezer  " } }.to_json,
           headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"].last).to eq({ "first" => "Tweezer" })
    end

    it "echoes the titles back so the panel can confirm what it sent" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: admin_headers
      expect(json[:titles]).to eq({ first: "Tweezer" })
    end

    it "accepts titles on a preview without writing them" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(track1.reload.title).to eq("Ghost")
    end

    it "hands the job nil when no titles are given" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: admin_headers
      expect(Admin::ShiftBoundaryJob.jobs.last["args"].last).to be_nil
    end

    it "omits the titles key from the response when none were given" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: admin_headers
      expect(json).not_to have_key(:titles)
    end

    it "422s on a blank title" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "" } }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:message]).to eq("Title for the first track cannot be blank")
    end

    it "422s on a whitespace-only title" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { second: "   " } }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:message]).to eq("Title for the second track cannot be blank")
    end

    it "enqueues nothing for a blank title" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
             params: { delta_s: 2.0, titles: { first: "" } }.to_json,
             headers: admin_headers
      }.not_to change(Admin::ShiftBoundaryJob.jobs, :size)
    end

    it "changes no title on a blank-title rejection" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "" } }.to_json,
           headers: admin_headers
      expect(track1.reload.title).to eq("Ghost")
    end

    it "enqueues nothing when titles come with an out-of-range delta" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
             params: { delta_s: 8.0, titles: { first: "Tweezer" } }.to_json,
             headers: admin_headers
      }.not_to change(Admin::ShiftBoundaryJob.jobs, :size)
    end

    it "returns 401 without a token when titles are sent" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin when titles are sent" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "changes no title when an unauthenticated apply with titles is rejected" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(track1.reload.title).to eq("Ghost")
    end

    it "changes no title when a non-admin apply with titles is rejected" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
           headers: user_headers
      expect(track1.reload.title).to eq("Ghost")
    end

    it "does not enqueue a job for an unauthorized apply with titles" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
             params: { delta_s: 2.0, titles: { first: "Tweezer" } }.to_json,
             headers: user_headers
      }.not_to change(Admin::ShiftBoundaryJob.jobs, :size)
    end

    it "422s when a side has no audio" do
      track2.mp3_audio.purge
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires a delta" do
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_preview",
           params: {}.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "changes no audio in the request itself" do
      keys = [ track1.mp3_audio.blob.key, track2.mp3_audio.blob.key ]
      post "/api/v2/admin/tracks/#{track1.id}/shift_boundary_apply",
           params: body, headers: admin_headers
      expect([ track1.reload.mp3_audio.blob.key, track2.reload.mp3_audio.blob.key ])
        .to eq(keys)
    end

    it "404s for an unknown track" do
      post "/api/v2/admin/tracks/0/shift_boundary_preview",
           params: body, headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v2/admin/shows/:date/tracks" do
    it "returns 401 without a token" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "inserts an empty draft track and shifts positions" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(show.tracks.reload.find_by(position: 2).title).to eq("Tuning")
      expect(track2.reload.position).to eq(3)
      expect(track3.reload.position).to eq(4)
    end

    it "inserts before position 1 without colliding" do
      create(:track, show:, position: 4, title: "Fourth", set: "1")
      create(:track, show:, position: 5, title: "Fifth", set: "1")

      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 1, title: "Intro", set: "1" }.to_json,
           headers: admin_headers

      expect(response).to have_http_status(:created)
      expect(positions_for(show)).to eq([ 1, 2, 3, 4, 5, 6 ])
      expect(show.tracks.reload.find_by(position: 1).title).to eq("Intro")
      expect(track1.reload.position).to eq(2)
    end

    it "appends at the end" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 4, title: "Encore", set: "E" }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(positions_for(show)).to eq([ 1, 2, 3, 4 ])
      expect(show.tracks.reload.find_by(position: 4).title).to eq("Encore")
    end

    it "creates the track with no songs and missing audio" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: admin_headers
      track = show.tracks.reload.find_by(position: 2)
      expect(track.songs).to be_empty
      expect(track.audio_status).to eq("missing")
    end

    it "422s on a published show because a published track requires songs" do
      show.update!(published: true)
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:message]).to include("at least one song")
    end

    it "does not leave shifted positions behind when the insert fails" do
      show.update!(published: true)
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "1" }.to_json,
           headers: admin_headers
      expect(positions_for(show)).to eq([ 1, 2, 3 ])
      expect(track2.reload.position).to eq(2)
      expect(track3.reload.position).to eq(3)
    end

    it "rejects an invalid set" do
      post "/api/v2/admin/shows/2025-08-01/tracks",
           params: { position: 2, title: "Tuning", set: "9" }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "trim endpoints" do
    before do
      track1.mp3_audio.attach(
        io: StringIO.new("bytes"), filename: "a.mp3", content_type: "audio/mpeg"
      )
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without a token on apply" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_apply",
           params: { trim_end: 100.0 }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user on apply" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_apply",
           params: { trim_end: 100.0 }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues a preview job" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
             params: { trim_end: 100.0 }.to_json, headers: admin_headers
      }.to change(Admin::TrimJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("trim_preview")
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the preview as a dry run" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: admin_headers
      expect(Admin::TrimJob.jobs.last["args"].last).to be(false)
    end

    it "enqueues an apply job that commits" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/trim_apply",
             params: { trim_end: 100.0 }.to_json, headers: admin_headers
      }.to change(Admin::TrimJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("trim_apply")
      expect(Admin::TrimJob.jobs.last["args"].last).to be(true)
    end

    it "passes the trim options through to the job" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_start: 3.5, trim_end: 100.0, fade_in: 0.5, fade_out: 4.0 }.to_json,
           headers: admin_headers
      opts = JSON.parse(Admin::TrimJob.jobs.last["args"][2])
      expect(opts).to eq(
        "trim_start" => 3.5, "trim_end" => 100.0, "fade_in" => 0.5, "fade_out" => 4.0
      )
    end

    it "applies default fades when omitted" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: admin_headers
      opts = JSON.parse(Admin::TrimJob.jobs.last["args"][2])
      expect(opts).to eq(
        "trim_start" => 0.0, "trim_end" => 100.0, "fade_in" => 0.2, "fade_out" => 6.0
      )
    end

    it "links the job to the track and its show" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: admin_headers
      expect(AdminJob.last).to have_attributes(track_id: track1.id, show_id: show.id)
    end

    it "422s without audio" do
      post "/api/v2/admin/tracks/#{track3.id}/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not enqueue a job without audio" do
      expect {
        post "/api/v2/admin/tracks/#{track3.id}/trim_preview",
             params: { trim_end: 100.0 }.to_json, headers: admin_headers
      }.not_to change(Admin::TrimJob.jobs, :size)
    end

    it "400s without trim_end" do
      post "/api/v2/admin/tracks/#{track1.id}/trim_preview",
           params: {}.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "404s for an unknown track" do
      post "/api/v2/admin/tracks/0/trim_preview",
           params: { trim_end: 100.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v2/admin/tracks/:id/replace_audio" do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("new bytes"), filename: "new.mp3", content_type: "audio/mpeg"
      )
    end

    before do
      track1.mp3_audio.attach(
        io: StringIO.new("old bytes"), filename: "old.mp3", content_type: "audio/mpeg"
      )
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
           params: { signed_id: blob.signed_id }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
           params: { signed_id: blob.signed_id }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "does not touch the track's audio when an unauthorized request is rejected" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
             params: { signed_id: blob.signed_id }.to_json, headers: user_headers
      }.not_to change { track1.reload.mp3_audio.blob.key }
    end

    it "does not enqueue a job for an unauthorized request" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
             params: { signed_id: blob.signed_id }.to_json, headers: user_headers
      }.not_to change(Admin::ReplaceAudioJob.jobs, :size)
    end

    it "enqueues the replace job" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
             params: { signed_id: blob.signed_id }.to_json, headers: admin_headers
      }.to change(Admin::ReplaceAudioJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "hands the job the track and the signed id" do
      post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
           params: { signed_id: blob.signed_id }.to_json, headers: admin_headers
      expect(Admin::ReplaceAudioJob.jobs.last["args"])
        .to eq([ track1.id, AdminJob.last.id, blob.signed_id ])
    end

    it "links the job to the track and its show" do
      post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
           params: { signed_id: blob.signed_id }.to_json, headers: admin_headers
      expect(AdminJob.last)
        .to have_attributes(kind: "replace_audio", track_id: track1.id, show_id: show.id)
    end

    it "400s without a signed id" do
      post "/api/v2/admin/tracks/#{track1.id}/replace_audio",
           params: {}.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "404s for an unknown track" do
      post "/api/v2/admin/tracks/0/replace_audio",
           params: { signed_id: blob.signed_id }.to_json, headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v2/admin/tracks/:id" do
    it "returns 401 without a token" do
      delete "/api/v2/admin/tracks/#{track2.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      delete "/api/v2/admin/tracks/#{track2.id}", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys and renumbers" do
      delete "/api/v2/admin/tracks/#{track2.id}", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(track3.reload.position).to eq(2)
    end

    it "leaves positions contiguous from 1 after deleting the first track" do
      create(:track, show:, position: 4, title: "Fourth", set: "1")
      create(:track, show:, position: 5, title: "Fifth", set: "1")
      delete "/api/v2/admin/tracks/#{track1.id}", headers: admin_headers
      expect(positions_for(show)).to eq([ 1, 2, 3, 4 ])
      expect(track2.reload.position).to eq(1)
    end

    it "closes pre-existing position gaps" do
      track2.update!(position: 10)
      track3.update!(position: 4)
      create(:track, show:, position: 5, title: "Fifth", set: "1")

      delete "/api/v2/admin/tracks/#{track1.id}", headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(positions_for(show)).to eq([ 1, 2, 3 ])
      expect(track2.reload.position).to eq(3)
    end

    it "destroys the track's likes and playlist entries" do
      create(:like, likable: track2)
      create(:playlist_track, track: track2)
      expect { delete "/api/v2/admin/tracks/#{track2.id}", headers: admin_headers }
        .to change(Like, :count).by(-1)
        .and change(PlaylistTrack, :count).by(-1)
    end

    it "404s for an unknown track" do
      delete "/api/v2/admin/tracks/0", headers: admin_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
