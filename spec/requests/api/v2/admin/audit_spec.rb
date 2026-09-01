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

    it "reports the original timestamps untouched" do
      get "/api/v2/admin/track_tags/orphaned", headers: admin_headers
      entry = json[:orphans].find { |o| o[:id] == orphan.id }
      expect(entry).to include(starts_at_second: 459, ends_at_second: 470)
    end

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

    it "refuses to set the flag" do
      healthy = create(:track_tag, track:, tag: create(:tag, name: "Jamcharts"),
                       starts_at_second: 10)
      patch "/api/v2/admin/track_tags/#{healthy.id}",
            params: { orphaned: true }.to_json, headers: admin_headers

      expect(response).to have_http_status(:bad_request)
      expect(healthy.reload.orphaned_at).to be_nil
    end

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
