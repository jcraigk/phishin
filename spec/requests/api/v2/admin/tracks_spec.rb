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

    # A naive implementation that assigns final positions one row at a time collides
    # with the (show_id, position) uniqueness validation partway through this move.
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

  describe "POST /api/v2/admin/tracks/:id/combine_preview and combine_apply" do
    it "returns 401 without a token" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_preview"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_preview", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without a token on apply" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_apply"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user on apply" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_apply", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    # Combine destroys a track row, so a rejected request has to leave the show
    # exactly as it found it - anonymous and non-admin alike.
    it "destroys no track when an unauthenticated apply is rejected" do
      expect {
        post "/api/v2/admin/tracks/#{track2.id}/combine_apply"
      }.not_to change { [ show.tracks.reload.count, track1.reload.title, positions_for(show) ] }
    end

    it "destroys no track when a non-admin apply is rejected" do
      expect {
        post "/api/v2/admin/tracks/#{track2.id}/combine_apply", headers: user_headers
      }.not_to change { [ show.tracks.reload.count, track1.reload.title, positions_for(show) ] }
    end

    it "does not enqueue a job for an unauthorized apply" do
      expect {
        post "/api/v2/admin/tracks/#{track2.id}/combine_apply", headers: user_headers
      }.not_to change(Admin::CombineTracksJob.jobs, :size)
    end

    it "returns a job id for a preview" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_preview", headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the preview without applying" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_preview", headers: admin_headers
      expect(Admin::CombineTracksJob.jobs.last["args"])
        .to eq([ track2.id, AdminJob.last.id, false ])
    end

    it "records the preview job kind" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_preview", headers: admin_headers
      expect(AdminJob.last).to have_attributes(kind: "combine_preview", track_id: track2.id)
    end

    it "enqueues the apply with the apply flag set" do
      post "/api/v2/admin/tracks/#{track2.id}/combine_apply", headers: admin_headers
      expect(Admin::CombineTracksJob.jobs.last["args"])
        .to eq([ track2.id, AdminJob.last.id, true ])
    end

    # The endpoint only enqueues, so the merge itself has to wait for the worker.
    it "changes nothing in the request itself" do
      expect {
        post "/api/v2/admin/tracks/#{track2.id}/combine_apply", headers: admin_headers
      }.not_to change { [ show.tracks.reload.count, track1.reload.title ] }
    end

    it "422s on the first track" do
      post "/api/v2/admin/tracks/#{track1.id}/combine_preview", headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "enqueues nothing for the first track" do
      expect {
        post "/api/v2/admin/tracks/#{track1.id}/combine_apply", headers: admin_headers
      }.not_to change(Admin::CombineTracksJob.jobs, :size)
    end

    it "404s for an unknown track" do
      post "/api/v2/admin/tracks/0/combine_preview", headers: admin_headers
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

    # Inserting at the front shifts every existing row; done ascending it collides.
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
      expect(json[:message]).to include("Songs")
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

  describe "POST /api/v2/admin/tracks/:id/split_preview and split_apply" do
    let!(:segue) do
      create(
        :track, show:, position: 4, title: "Ghost > Free", set: "1",
                songs: [ song_a, song_b ]
      ).tap do |track|
        track.mp3_audio.attach(
          io: StringIO.new("bytes"), filename: "a.mp3", content_type: "audio/mpeg"
        )
      end
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without a token on apply" do
      post "/api/v2/admin/tracks/#{segue.id}/split_apply",
           params: { cut_s: 30.0 }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user on apply" do
      post "/api/v2/admin/tracks/#{segue.id}/split_apply",
           params: { cut_s: 30.0 }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "does not touch the track when an unauthorized apply is rejected" do
      expect {
        post "/api/v2/admin/tracks/#{segue.id}/split_apply",
             params: { cut_s: 30.0 }.to_json, headers: user_headers
      }.not_to change { [ show.tracks.reload.count, segue.reload.title ] }
    end

    it "does not enqueue a job for an unauthorized apply" do
      expect {
        post "/api/v2/admin/tracks/#{segue.id}/split_apply",
             params: { cut_s: 30.0 }.to_json, headers: user_headers
      }.not_to change(Admin::SplitJob.jobs, :size)
    end

    it "enqueues a preview job" do
      expect {
        post "/api/v2/admin/tracks/#{segue.id}/split_preview",
             params: { cut_s: 30.0 }.to_json, headers: admin_headers
      }.to change(Admin::SplitJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("split_preview")
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the preview as a dry run" do
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(Admin::SplitJob.jobs.last["args"]).to eq([ segue.id, AdminJob.last.id, 30.0, false ])
    end

    it "enqueues an apply job that commits" do
      expect {
        post "/api/v2/admin/tracks/#{segue.id}/split_apply",
             params: { cut_s: 30.0 }.to_json, headers: admin_headers
      }.to change(Admin::SplitJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(AdminJob.last.kind).to eq("split_apply")
      expect(Admin::SplitJob.jobs.last["args"].last).to be(true)
    end

    it "links the job to the track and its show" do
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(AdminJob.last).to have_attributes(track_id: segue.id, show_id: show.id)
    end

    it "422s for a title without a segue" do
      segue.update!(title: "Ghost")
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:message]).to include("exactly one")
    end

    it "does not enqueue a job for a title without a segue" do
      segue.update!(title: "Ghost")
      expect {
        post "/api/v2/admin/tracks/#{segue.id}/split_preview",
             params: { cut_s: 30.0 }.to_json, headers: admin_headers
      }.not_to change(Admin::SplitJob.jobs, :size)
    end

    it "422s for a title with two segues" do
      segue.update!(title: "Ghost > Free > Ghost")
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    # The service splits on "->" as readily as ">", so the endpoint's guard must
    # not turn away a title it would have accepted.
    it "accepts the arrow form of a segue" do
      segue.update!(title: "Ghost -> Free")
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:created)
    end

    it "422s without audio" do
      no_audio = create(:track, show:, position: 5, title: "Ghost > Free", set: "1")
      post "/api/v2/admin/tracks/#{no_audio.id}/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "400s without cut_s" do
      post "/api/v2/admin/tracks/#{segue.id}/split_preview",
           params: {}.to_json, headers: admin_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "404s for an unknown track" do
      post "/api/v2/admin/tracks/0/split_preview",
           params: { cut_s: 30.0 }.to_json, headers: admin_headers
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
