require "rails_helper"

RSpec.describe "Admin direct uploads" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  let(:blob_params) do
    {
      blob: {
        filename: "I 01 Tweezer.mp3",
        byte_size: 14,
        checksum: Digest::MD5.base64digest("fake mp3 bytes"),
        content_type: "audio/mpeg"
      }
    }
  end

  def post_upload(headers = {})
    post "/admin/direct_uploads",
         params: blob_params.to_json,
         headers: headers.merge("CONTENT_TYPE" => "application/json")
  end

  it "returns 401 without a token" do
    expect { post_upload }.not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 with a garbage token" do
    expect { post_upload("X-Auth-Token" => "not-a-jwt") }
      .not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 403 for a non-admin user" do
    expect { post_upload("X-Auth-Token" => UserJwtService.call(user)) }
      .not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "creates a blob for an admin and preserves the original filename" do
    post_upload("X-Auth-Token" => UserJwtService.call(admin))
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["filename"]).to eq("I 01 Tweezer.mp3")
    expect(body["direct_upload"]["url"]).to be_present
    expect(ActiveStorage::Blob.find_signed(body["signed_id"]).filename.to_s)
      .to eq("I 01 Tweezer.mp3")
  end

  it "stores segue characters unsanitized on the blob" do
    blob_params[:blob][:filename] = "II 03 Harry Hood > Wilson.mp3"
    post_upload("X-Auth-Token" => UserJwtService.call(admin))
    blob = ActiveStorage::Blob.find_signed(JSON.parse(response.body)["signed_id"])
    expect(Show.original_filename(blob)).to eq("II 03 Harry Hood > Wilson.mp3")
  end
end
