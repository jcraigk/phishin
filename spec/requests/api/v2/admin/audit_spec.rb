require "rails_helper"

RSpec.describe "API v2 Admin Audit" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:show) { create(:show, date: "2025-08-01", published: false) }
  let!(:track) { create(:track, show:, position: 1, title: "Possum", duration: 600_000) }
  let!(:tag) { create(:tag, name: "Tease") }

  def token_for(u) = UserJwtService.call(u)

  def admin_headers
    { "X-Auth-Token" => token_for(admin), "CONTENT_TYPE" => "application/json" }
  end

  def user_headers
    { "X-Auth-Token" => token_for(user), "CONTENT_TYPE" => "application/json" }
  end

  def anon_headers = { "CONTENT_TYPE" => "application/json" }

  def json = JSON.parse(response.body, symbolize_names: true)

  describe "GET /api/v2/admin/shows/:date/history" do
    it "returns 401 without a token" do
      get "/api/v2/admin/shows/2025-08-01/history", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/shows/2025-08-01/history", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "groups edits under the track they describe, newest first" do
      older = create(:track_edit, track:, show:, operation: "trim",
                     created_at: 2.days.ago)
      newer = create(:track_edit, track:, show:, operation: "shift_boundary",
                     created_at: 1.hour.ago)

      get "/api/v2/admin/shows/2025-08-01/history", headers: admin_headers

      expect(response).to have_http_status(:ok)
      group = json[:history].find { |g| g[:track_id] == track.id }
      expect(group).to include(position: 1, title: "Possum")
      expect(group[:edits].map { |e| e[:id] }).to eq([ newer.id, older.id ])
    end

    it "delivers the payload whole, including keys no UI anticipates" do
      create(
        :track_edit,
        track:, show:, operation: "trim",
        payload: {
          "duration_before_s" => 600.0,
          "duration_after_s" => 597.0,
          "delta_s" => -3.0,
          "shifted" => [ { "type" => "TrackTag", "id" => 7, "from" => 66, "to" => 63 } ],
          "clamped" => [],
          "orphaned" => [],
          "backup_path" => "/tmp/original.mp3",
          "something_new" => "kept anyway"
        }
      )

      get "/api/v2/admin/shows/2025-08-01/history", headers: admin_headers

      payload = json[:history].find { |g| g[:track_id] == track.id }[:edits].first[:payload]
      expect(payload[:delta_s]).to eq(-3.0)
      expect(payload[:shifted].first).to include(type: "TrackTag", from: 66, to: 63)
      expect(payload[:backup_path]).to eq("/tmp/original.mp3")
      expect(payload[:something_new]).to eq("kept anyway")
    end

    # The reason the history is fetched per show rather than per track. A combine
    # nullifies track_id, so no per-track query can reach these rows.
    it "reaches edits whose track was destroyed, in a group of their own" do
      doomed = create(:track, show:, position: 2, title: "Gone")
      edit = create(:track_edit, track: doomed, show:, operation: "combine")
      doomed.destroy!
      expect(edit.reload.track_id).to be_nil

      get "/api/v2/admin/shows/2025-08-01/history", headers: admin_headers

      gone = json[:history].find { |g| g[:track_id].nil? }
      expect(gone[:edits].map { |e| e[:id] }).to eq([ edit.id ])
      expect(gone[:edits].first[:operation]).to eq("combine")
    end

    it "omits the destroyed-track group when nothing was destroyed" do
      create(:track_edit, track:, show:, operation: "trim")
      get "/api/v2/admin/shows/2025-08-01/history", headers: admin_headers
      expect(json[:history].map { |g| g[:track_id] }).not_to include(nil)
    end

    it "renders a retired operation rather than rejecting it" do
      create(:track_edit, track:, show:, operation: "split")
      get "/api/v2/admin/shows/2025-08-01/history", headers: admin_headers
      operations = json[:history].flat_map { |g| g[:edits].map { |e| e[:operation] } }
      expect(operations).to include("split")
    end
  end

  describe "GET /api/v2/admin/track_tags/orphaned" do
    let!(:orphan) do
      create(
        :track_tag, track:, tag:, starts_at_second: 459, ends_at_second: 470,
        orphaned_at: Time.current, orphan_reason: TimestampShifter::REASON_PAST_END
      )
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/track_tags/orphaned", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/track_tags/orphaned", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "lists the orphan with its track and show" do
      get "/api/v2/admin/track_tags/orphaned", headers: admin_headers

      expect(response).to have_http_status(:ok)
      entry = json[:orphans].find { |o| o[:id] == orphan.id }
      expect(entry).to include(
        tag_name: "Tease",
        orphan_reason: "past_new_end",
        track_id: track.id,
        track_title: "Possum",
        track_position: 1,
        show_date: "2025-08-01"
      )
    end

    # The numbers are evidence of where the tag used to point. Recomputing or
    # blanking them would destroy the only record of what it described.
    it "reports the original timestamps untouched" do
      get "/api/v2/admin/track_tags/orphaned", headers: admin_headers
      entry = json[:orphans].find { |o| o[:id] == orphan.id }
      expect(entry).to include(starts_at_second: 459, ends_at_second: 470)
    end

    # The shifter orphans on starts_at_second || ends_at_second, so a tag with
    # only an end reaches the queue and has to render without a start.
    it "lists an orphan that carries only an end timestamp" do
      end_only = create(
        :track_tag, track:, tag: create(:tag, name: "Alt Version"),
        starts_at_second: nil, ends_at_second: 900,
        orphaned_at: Time.current, orphan_reason: TimestampShifter::REASON_PAST_END
      )
      get "/api/v2/admin/track_tags/orphaned", headers: admin_headers
      entry = json[:orphans].find { |o| o[:id] == end_only.id }
      expect(entry).to include(starts_at_second: nil, ends_at_second: 900)
    end

    it "excludes tags that are not orphaned" do
      healthy = create(:track_tag, track:, tag: create(:tag, name: "Jamcharts"),
                       starts_at_second: 10)
      get "/api/v2/admin/track_tags/orphaned", headers: admin_headers
      expect(json[:orphans].map { |o| o[:id] }).not_to include(healthy.id)
    end
  end

  describe "PATCH /api/v2/admin/track_tags/:id resolving an orphan" do
    let!(:orphan) do
      create(
        :track_tag, track:, tag:, starts_at_second: 459,
        orphaned_at: Time.current, orphan_reason: TimestampShifter::REASON_PAST_END
      )
    end

    it "returns 401 without a token and clears nothing" do
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { orphaned: false }.to_json, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(orphan.reload.orphaned_at).to be_present
    end

    it "returns 403 for a non-admin user and clears nothing" do
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { orphaned: false }.to_json, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(orphan.reload.orphaned_at).to be_present
    end

    it "clears the flag and its reason together" do
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { orphaned: false }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(orphan.reload.orphaned_at).to be_nil
      expect(orphan.orphan_reason).to be_nil
    end

    it "corrects the timestamps and clears the flag in one request" do
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { starts_at_second: 300, orphaned: false }.to_json,
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(orphan.reload.starts_at_second).to eq(300)
      expect(orphan.orphaned_at).to be_nil
    end

    it "leaves the flag alone when the request does not mention it" do
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { notes: "still wrong" }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(orphan.reload.notes).to eq("still wrong")
      expect(orphan.orphaned_at).to be_present
    end

    # Only an audio operation may declare a tag orphaned. Accepting true here
    # would let a hand edit fabricate a record of an operation that never ran.
    it "refuses to set the flag" do
      healthy = create(:track_tag, track:, tag: create(:tag, name: "Jamcharts"),
                       starts_at_second: 10)
      patch "/api/v2/admin/track_tags/#{healthy.id}",
            params: { orphaned: true }.to_json, headers: admin_headers

      expect(response).to have_http_status(:bad_request)
      expect(healthy.reload.orphaned_at).to be_nil
    end

    # The Tags tab sends the corrected second and the flag together for the same
    # reason the queue does: a saved timestamp is the admin answering the
    # question the flag was asking.
    it "resolves when only the end timestamp is corrected" do
      orphan.update_columns(starts_at_second: nil, ends_at_second: 900)
      patch "/api/v2/admin/track_tags/#{orphan.id}",
            params: { ends_at_second: 280, orphaned: false }.to_json,
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(orphan.reload.ends_at_second).to eq(280)
      expect(orphan.orphaned_at).to be_nil
    end

    it "reports the orphan state back in the track payload" do
      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      entry = json[:tracks].first[:track_tags].find { |t| t[:id] == orphan.id }
      expect(entry[:orphan_reason]).to eq("past_new_end")
    end
  end
end
