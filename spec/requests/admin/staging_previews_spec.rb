require "rails_helper"

RSpec.describe "Admin staging preview audio" do
  let(:show) { create(:show, date: "2025-08-01", published: false, audio_status: "missing") }
  let(:dir) { Admin::StagingDir.new(show) }
  let(:bytes) { "\xFF\xFB#{'a' * 98}".b }
  let(:url) { "/admin/staging_preview?token=#{CGI.escape(Admin::StagingPreviewsController.token_for(show))}" }

  before do
    dir.reset!
    File.binwrite(dir.preview, bytes)
  end

  after { dir.remove! }

  it "streams the preview for a valid token" do
    get url
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("audio/mpeg")
    expect(response.body).to eq(bytes)
  end

  it "serves byte ranges so the browser can seek without downloading the whole show" do
    get url, headers: { "Range" => "bytes=10-19" }
    expect(response).to have_http_status(:partial_content)
    expect(response.body).to eq(bytes[10..19])
  end

  it "404s for a forged token" do
    get "/admin/staging_preview?token=nope"
    expect(response).to have_http_status(:not_found)
  end

  it "404s once the token expires" do
    token_url = url
    travel(Admin::StagingPreviewsController::TTL + 1.minute) { get token_url }
    expect(response).to have_http_status(:not_found)
  end

  it "404s when the preview has not been rendered" do
    FileUtils.rm_f(dir.preview)
    get url
    expect(response).to have_http_status(:not_found)
  end
end
