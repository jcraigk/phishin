require "rails_helper"

RSpec.describe "API v2 Admin Taggings" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:show) { create(:show, date: "2025-08-01", published: false) }
  let!(:track) { create(:track, show:, position: 1, songs: [ create(:song) ]) }
  let!(:tag) { create(:tag, name: "SBD") }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    { "X-Auth-Token" => token_for(admin), "CONTENT_TYPE" => "application/json" }
  end

  def user_headers
    { "X-Auth-Token" => token_for(user), "CONTENT_TYPE" => "application/json" }
  end

  def anon_headers
    { "CONTENT_TYPE" => "application/json" }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  describe "GET /api/v2/admin/tags" do
    it "returns 401 without a token" do
      get "/api/v2/admin/tags", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/tags", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "lists tags with id, name, and group" do
      get "/api/v2/admin/tags", headers: admin_headers
      expect(response).to have_http_status(:ok)
      entry = json[:tags].find { |t| t[:name] == "SBD" }
      expect(entry).to include(id: tag.id, name: "SBD", group: tag.group)
    end

  end

  describe "POST /api/v2/admin/shows/:date/pnet_tag_check" do
    it "enqueues a check job" do
      expect {
        post "/api/v2/admin/shows/#{show.date}/pnet_tag_check", headers: admin_headers
      }.to change(Admin::PnetTagCheckJob.jobs, :size).by(1)
      expect(response).to have_http_status(:created)
      expect(json[:job_id]).to eq(AdminJob.last.id)
      expect(AdminJob.last.kind).to eq("pnet_tag_check")
    end

    it "returns 401 without a token" do
      post "/api/v2/admin/shows/#{show.date}/pnet_tag_check"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v2/admin/shows/:date/show_tags" do
    let(:body) { { tag_id: tag.id, notes: "Soundboard source" }.to_json }

    it "returns 401 without a token and creates nothing" do
      post "/api/v2/admin/shows/2025-08-01/show_tags", params: body, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(show.reload.show_tags.count).to eq(0)
    end

    it "returns 403 for a non-admin user and creates nothing" do
      post "/api/v2/admin/shows/2025-08-01/show_tags", params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(show.reload.show_tags.count).to eq(0)
    end

    it "adds a show tag and returns the editor payload" do
      post "/api/v2/admin/shows/2025-08-01/show_tags", params: body, headers: admin_headers
      expect(response).to have_http_status(:created)

      show_tag = show.reload.show_tags.first
      expect(show_tag.notes).to eq("Soundboard source")
      expect(show_tag.tag).to eq(tag)
      expect(json[:show_tags]).to contain_exactly(
        hash_including(id: show_tag.id, tag_id: tag.id, tag_name: "SBD", notes: "Soundboard source")
      )
    end

    it "returns 422 when the tag is already applied" do
      show.show_tags.create!(tag:)
      post "/api/v2/admin/shows/2025-08-01/show_tags", params: body, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(show.reload.show_tags.count).to eq(1)
    end
  end

  describe "PATCH /api/v2/admin/show_tags/:id" do
    let!(:show_tag) { show.show_tags.create!(tag:, notes: "Original") }
    let(:body) { { notes: "Updated" }.to_json }

    it "returns 401 without a token and changes nothing" do
      patch "/api/v2/admin/show_tags/#{show_tag.id}", params: body, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(show_tag.reload.notes).to eq("Original")
    end

    it "returns 403 for a non-admin user and changes nothing" do
      patch "/api/v2/admin/show_tags/#{show_tag.id}", params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(show_tag.reload.notes).to eq("Original")
    end

    it "updates the notes and returns the editor payload" do
      patch "/api/v2/admin/show_tags/#{show_tag.id}", params: body, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(show_tag.reload.notes).to eq("Updated")
      expect(json[:show_tags].first[:notes]).to eq("Updated")
    end
  end

  describe "DELETE /api/v2/admin/show_tags/:id" do
    let!(:show_tag) { show.show_tags.create!(tag:) }

    it "returns 401 without a token and removes nothing" do
      delete "/api/v2/admin/show_tags/#{show_tag.id}", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(show.reload.show_tags.count).to eq(1)
    end

    it "returns 403 for a non-admin user and removes nothing" do
      delete "/api/v2/admin/show_tags/#{show_tag.id}", headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(show.reload.show_tags.count).to eq(1)
    end

    it "removes the association without destroying the tag" do
      expect {
        delete "/api/v2/admin/show_tags/#{show_tag.id}", headers: admin_headers
      }.not_to change(Tag, :count)
      expect(response).to have_http_status(:ok)
      expect(show.reload.show_tags.count).to eq(0)
      expect(json[:show_tags]).to eq([])
    end
  end

  describe "POST /api/v2/admin/tracks/:id/track_tags" do
    let(:body) do
      { tag_id: tag.id, starts_at_second: 120, ends_at_second: 300, notes: "Jam" }.to_json
    end

    it "returns 401 without a token and creates nothing" do
      post "/api/v2/admin/tracks/#{track.id}/track_tags", params: body, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(track.reload.track_tags.count).to eq(0)
    end

    it "returns 403 for a non-admin user and creates nothing" do
      post "/api/v2/admin/tracks/#{track.id}/track_tags", params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(track.reload.track_tags.count).to eq(0)
    end

    it "adds a track tag with timing and returns the track payload" do
      post "/api/v2/admin/tracks/#{track.id}/track_tags", params: body, headers: admin_headers
      expect(response).to have_http_status(:created)

      track_tag = track.reload.track_tags.first
      expect(track_tag.starts_at_second).to eq(120)
      expect(track_tag.ends_at_second).to eq(300)
      expect(json[:track_tags]).to contain_exactly(
        hash_including(
          id: track_tag.id,
          tag_id: tag.id,
          tag_name: "SBD",
          notes: "Jam",
          starts_at_second: 120,
          ends_at_second: 300,
          transcript: nil
        )
      )
    end
  end

  describe "PATCH /api/v2/admin/track_tags/:id" do
    let!(:track_tag) { track.track_tags.create!(tag:, transcript: "old") }
    let(:body) { { transcript: "words", starts_at_second: 42 }.to_json }

    it "returns 401 without a token and changes nothing" do
      patch "/api/v2/admin/track_tags/#{track_tag.id}", params: body, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(track_tag.reload.transcript).to eq("old")
    end

    it "returns 403 for a non-admin user and changes nothing" do
      patch "/api/v2/admin/track_tags/#{track_tag.id}", params: body, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(track_tag.reload.transcript).to eq("old")
    end

    it "updates the transcript and timing and returns the track payload" do
      patch "/api/v2/admin/track_tags/#{track_tag.id}", params: body, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(track_tag.reload.transcript).to eq("words")
      expect(track_tag.starts_at_second).to eq(42)
      expect(json[:track_tags].first).to include(transcript: "words", starts_at_second: 42)
    end
  end

  describe "DELETE /api/v2/admin/track_tags/:id" do
    let!(:track_tag) { track.track_tags.create!(tag:) }

    it "returns 401 without a token and removes nothing" do
      delete "/api/v2/admin/track_tags/#{track_tag.id}", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(track.reload.track_tags.count).to eq(1)
    end

    it "returns 403 for a non-admin user and removes nothing" do
      delete "/api/v2/admin/track_tags/#{track_tag.id}", headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(track.reload.track_tags.count).to eq(1)
    end

    it "removes the association without destroying the tag" do
      expect {
        delete "/api/v2/admin/track_tags/#{track_tag.id}", headers: admin_headers
      }.not_to change(Tag, :count)
      expect(response).to have_http_status(:ok)
      expect(track.reload.track_tags.count).to eq(0)
      expect(json[:track_tags]).to eq([])
    end
  end

  describe "editor payload tags" do
    it "includes show tags and nested track tags" do
      show.show_tags.create!(tag:, notes: "Source")
      track.track_tags.create!(tag:, starts_at_second: 5)

      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:show_tags].first).to include(tag_name: "SBD", notes: "Source")
      expect(json[:tracks].first[:track_tags].first).to include(
        tag_name: "SBD", starts_at_second: 5
      )
    end
  end
end
