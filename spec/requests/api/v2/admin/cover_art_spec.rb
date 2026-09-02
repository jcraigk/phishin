require "rails_helper"

RSpec.describe "API v2 Admin Cover Art" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:show) { create(:show, date: "2025-08-01", cover_art_prompt: "a red barn") }

  def token_for(other)
    UserJwtService.call(other)
  end

  def admin_headers
    { "X-Auth-Token" => token_for(admin) }
  end

  def json_headers(headers = admin_headers)
    headers.merge("CONTENT_TYPE" => "application/json")
  end

  def upload_image(filename = "candidate.png")
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("spec/fixtures/files/cover-art-large.jpg")),
      filename:,
      content_type: "image/png"
    )
  end

  describe "POST /api/v2/admin/shows/:date/cover_art/regenerate_prompt" do
    let(:path) { "/api/v2/admin/shows/2025-08-01/cover_art/regenerate_prompt" }

    it "creates a prompt job" do
      post path, headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "cover_art_prompt", show_id: show.id)
    end

    it "enqueues the prompt job" do
      post path, headers: admin_headers
      expect(Admin::RegenerateCoverArtPromptJob.jobs.size).to eq(1)
    end

    it "returns the job id" do
      post path, headers: admin_headers
      expect(JSON.parse(response.body)["job_id"]).to eq(AdminJob.last.id)
    end

    it "returns 401 without a token" do
      post path
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post path, headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "creates no job and enqueues nothing when unauthorized" do
      post path
      post path, headers: { "X-Auth-Token" => token_for(user) }
      expect(AdminJob.count).to eq(0)
      expect(Admin::RegenerateCoverArtPromptJob.jobs).to be_empty
    end
  end

  describe "POST /api/v2/admin/shows/:date/cover_art/generate" do
    let(:path) { "/api/v2/admin/shows/2025-08-01/cover_art/generate" }

    it "creates a generate job" do
      post path, headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "cover_art_generate", show_id: show.id)
    end

    it "enqueues the generate job" do
      post path, headers: admin_headers
      expect(Admin::GenerateCoverArtJob.jobs.size).to eq(1)
    end

    it "422s when the show has neither a prompt nor a parent" do
      show.update!(cover_art_prompt: nil)
      post path, headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "enqueues nothing when the show has neither a prompt nor a parent" do
      show.update!(cover_art_prompt: nil)
      post path, headers: admin_headers
      expect(Admin::GenerateCoverArtJob.jobs).to be_empty
      expect(AdminJob.count).to eq(0)
    end

    it "allows a parent-linked show with no prompt of its own" do
      parent = create(:show, date: "2025-07-31")
      show.update!(cover_art_prompt: nil, cover_art_parent_show_id: parent.id)
      post path, headers: admin_headers
      expect(response).to have_http_status(:created)
    end

    it "returns 401 without a token" do
      post path
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post path, headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "creates no job and enqueues no generation when unauthorized" do
      post path
      post path, headers: { "X-Auth-Token" => token_for(user) }
      expect(AdminJob.count).to eq(0)
      expect(Admin::GenerateCoverArtJob.jobs).to be_empty
    end
  end

  describe "POST /api/v2/admin/shows/:date/cover_art/upload" do
    let(:path) { "/api/v2/admin/shows/2025-08-01/cover_art/upload" }

    it "attaches the upload as a candidate" do
      blob = upload_image
      post path, params: { signed_id: blob.signed_id }.to_json, headers: json_headers
      expect(response).to have_http_status(:created)
      expect(show.reload.cover_art_candidates.map(&:blob)).to eq([ blob ])
    end

    it "returns the candidate in the cover art payload" do
      blob = upload_image
      post path, params: { signed_id: blob.signed_id }.to_json, headers: json_headers
      candidates = JSON.parse(response.body).dig("cover_art", "candidates")
      expect(candidates).to eq(
        [ {
          "blob_key" => blob.key,
          "url" => "#{App.base_url}/blob/#{blob.key}.png",
          "cost" => nil,
          "prompt" => nil,
          "edits" => []
        } ]
      )
    end

    it "keeps earlier candidates" do
      first = upload_image("first.png")
      show.cover_art_candidates.attach(first)
      post path, params: { signed_id: upload_image("second.png").signed_id }.to_json,
           headers: json_headers
      expect(show.reload.cover_art_candidates.count).to eq(2)
    end

    it "does not touch the show's current cover art" do
      show.cover_art.attach(
        io: StringIO.new("existing"), filename: "current.jpg", content_type: "image/jpeg"
      )
      current_key = show.cover_art.blob.key
      post path, params: { signed_id: upload_image.signed_id }.to_json, headers: json_headers
      expect(show.reload.cover_art.blob.key).to eq(current_key)
    end

    it "422s on an unknown signed id" do
      post path, params: { signed_id: "nonsense" }.to_json, headers: json_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(show.reload.cover_art_candidates).to be_empty
    end

    it "returns 401 without a token" do
      post path, params: { signed_id: upload_image.signed_id }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post path, params: { signed_id: upload_image.signed_id }.to_json,
           headers: json_headers("X-Auth-Token" => token_for(user))
      expect(response).to have_http_status(:forbidden)
    end

    it "attaches no candidate when unauthorized" do
      blob = upload_image
      post path, params: { signed_id: blob.signed_id }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      post path, params: { signed_id: blob.signed_id }.to_json,
           headers: json_headers("X-Auth-Token" => token_for(user))
      expect(show.reload.cover_art_candidates).to be_empty
    end
  end

  describe "POST /api/v2/admin/shows/:date/cover_art/ai_edit" do
    let(:path) { "/api/v2/admin/shows/2025-08-01/cover_art/ai_edit" }
    let(:candidate) { upload_image }
    let(:body) { { source_blob_key: candidate.key, edit_prompt: "make it blue" }.to_json }

    before { show.cover_art_candidates.attach(candidate) }

    it "creates an edit job" do
      post path, params: body, headers: json_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "cover_art_edit", show_id: show.id)
    end

    it "enqueues the edit job with the source key and prompt" do
      post path, params: body, headers: json_headers
      expect(Admin::EditCoverArtJob.jobs.last["args"])
        .to eq([ show.id, AdminJob.last.id, candidate.key, "make it blue" ])
    end

    it "accepts the show's current cover art as the source" do
      show.cover_art.attach(
        io: StringIO.new("existing"), filename: "current.jpg", content_type: "image/jpeg"
      )
      post path,
           params: { source_blob_key: show.cover_art.blob.key, edit_prompt: "bluer" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:created)
    end

    it "422s on a blob this show does not own" do
      other = upload_image("elsewhere.png")
      post path, params: { source_blob_key: other.key, edit_prompt: "blue" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(Admin::EditCoverArtJob.jobs).to be_empty
    end

    it "returns 401 without a token" do
      post path, params: body, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post path, params: body, headers: json_headers("X-Auth-Token" => token_for(user))
      expect(response).to have_http_status(:forbidden)
    end

    it "creates no job and enqueues no edit when unauthorized" do
      post path, params: body, headers: { "CONTENT_TYPE" => "application/json" }
      post path, params: body, headers: json_headers("X-Auth-Token" => token_for(user))
      expect(AdminJob.count).to eq(0)
      expect(Admin::EditCoverArtJob.jobs).to be_empty
    end
  end

  describe "POST /api/v2/admin/shows/:date/cover_art/select" do
    let(:path) { "/api/v2/admin/shows/2025-08-01/cover_art/select" }
    let(:candidate) { upload_image }
    let(:body) { { blob_key: candidate.key, zoom: 0 }.to_json }

    before { show.cover_art_candidates.attach(candidate) }

    it "creates a select job" do
      post path, params: body, headers: json_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "cover_art_select", show_id: show.id)
    end

    it "enqueues the select job with the blob key and zoom" do
      post path, params: { blob_key: candidate.key, zoom: 20 }.to_json, headers: json_headers
      expect(Admin::SelectCoverArtJob.jobs.last["args"])
        .to eq([ show.id, AdminJob.last.id, candidate.key, 20 ])
    end

    it "defaults zoom to zero" do
      post path, params: { blob_key: candidate.key }.to_json, headers: json_headers
      expect(Admin::SelectCoverArtJob.jobs.last["args"].last).to eq(0)
    end

    it "returns the job id" do
      post path, params: body, headers: json_headers
      expect(JSON.parse(response.body)["job_id"]).to eq(AdminJob.last.id)
    end

    it "422s on a blob this show does not hold as a candidate" do
      post path, params: { blob_key: upload_image("elsewhere.png").key }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(Admin::SelectCoverArtJob.jobs).to be_empty
    end

    it "400s on a zoom outside 0..50" do
      post path, params: { blob_key: candidate.key, zoom: 80 }.to_json, headers: json_headers
      expect(response).to have_http_status(:bad_request)
      expect(Admin::SelectCoverArtJob.jobs).to be_empty
    end

    it "returns 401 without a token" do
      post path, params: body, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      post path, params: body, headers: json_headers("X-Auth-Token" => token_for(user))
      expect(response).to have_http_status(:forbidden)
    end

    it "creates no job and enqueues no selection when unauthorized" do
      post path, params: body, headers: { "CONTENT_TYPE" => "application/json" }
      post path, params: body, headers: json_headers("X-Auth-Token" => token_for(user))
      expect(AdminJob.count).to eq(0)
      expect(Admin::SelectCoverArtJob.jobs).to be_empty
    end

    it "changes no cover art when unauthorized" do
      post path, params: body, headers: { "CONTENT_TYPE" => "application/json" }
      post path, params: body, headers: json_headers("X-Auth-Token" => token_for(user))
      show.reload
      expect(show.cover_art).not_to be_attached
      expect(show.cover_art_candidates.count).to eq(1)
    end
  end

  describe "cover art in the editor payload" do
    it "includes the prompt fields" do
      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(JSON.parse(response.body)["cover_art"]).to include(
        "prompt" => "a red barn", "parent_show_id" => nil, "candidates" => []
      )
    end

    it "includes candidates once attached" do
      blob = upload_image
      show.cover_art_candidates.attach(blob)
      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(JSON.parse(response.body).dig("cover_art", "candidates", 0, "blob_key"))
        .to eq(blob.key)
    end

    it "reports no current url when the show has no cover art" do
      get "/api/v2/admin/shows/2025-08-01", headers: admin_headers
      expect(JSON.parse(response.body).dig("cover_art", "current_url")).to be_nil
    end
  end

  describe "PATCH /api/v2/admin/shows/:date with cover art fields" do
    it "updates the prompt" do
      patch "/api/v2/admin/shows/2025-08-01",
            params: { cover_art_prompt: "a blue barn" }.to_json,
            headers: json_headers
      expect(show.reload.cover_art_prompt).to eq("a blue barn")
    end

    it "updates the parent show link" do
      parent = create(:show, date: "2025-07-31")
      patch "/api/v2/admin/shows/2025-08-01",
            params: { cover_art_parent_show_id: parent.id }.to_json,
            headers: json_headers
      expect(show.reload.cover_art_parent_show_id).to eq(parent.id)
    end

    it "returns the updated cover art section" do
      patch "/api/v2/admin/shows/2025-08-01",
            params: { cover_art_prompt: "a green barn" }.to_json,
            headers: json_headers
      expect(JSON.parse(response.body).dig("cover_art", "prompt")).to eq("a green barn")
    end
  end
end
