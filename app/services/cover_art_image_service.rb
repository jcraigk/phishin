class CoverArtImageService < ApplicationService
  param :show
  option :dry_run, default: -> { false }
  option :source_blob_key, default: -> { nil }
  option :edit_prompt, default: -> { nil }

  def call
    generate_and_save_cover_art
  end

  private

  def editing?
    source_blob_key.present? && edit_prompt.present?
  end

  def generate_and_save_cover_art
    if show.cover_art_parent_show_id && !editing?
      parent_show = Show.find(show.cover_art_parent_show_id)
      show.cover_art.attach(parent_show.cover_art.blob) unless dry_run
      return
    end

    response = editing? ? edit_request : generate_request
    raise "Failed to generate cover art: #{response.body}" unless response.success?

    result = JSON.parse(response.body)
    url = upload_candidate(result["data"].first["b64_json"])
    show.attach_cover_art_by_url(url) unless dry_run
    url
  end

  def generate_request
    Typhoeus.post(
      "https://api.openai.com/v1/images/generations",
      headers: {
        "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_TOKEN")}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-image-2",
        prompt: show.cover_art_prompt,
        n: 1,
        size: "1024x1024",
        quality: "high"
      }.to_json
    )
  end

  def edit_request
    blob = ActiveStorage::Blob.find_by!(key: source_blob_key)
    Tempfile.create([ "cover_art_source_", ".png" ]) do |tmp|
      tmp.binmode
      tmp.write(blob.download)
      tmp.rewind
      return Typhoeus.post(
        "https://api.openai.com/v1/images/edits",
        headers: {
          "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_TOKEN")}"
        },
        body: {
          model: "gpt-image-2",
          prompt: edit_prompt,
          n: "1",
          size: "1024x1024",
          quality: "high",
          image: tmp
        }
      )
    end
  end

  def upload_candidate(b64)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(b64)),
      filename: "cover_art_candidate_#{SecureRandom.hex}.png",
      content_type: "image/png"
    )
    "#{App.base_url}/blob/#{blob.key}.png"
  end
end
