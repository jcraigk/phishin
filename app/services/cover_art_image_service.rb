class CoverArtImageService < ApplicationService
  param :show
  option :dry_run, default: -> { false }
  option :source_blob_key, default: -> { nil }
  option :edit_prompt, default: -> { nil }
  option :prompt_override, default: -> { nil }

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
    url = upload_candidate(result["data"].first["b64_json"], prompt_trail)
    show.attach_cover_art_by_url(url) unless dry_run
    url
  end

  def generation_prompt
    prompt_override.presence || show.cover_art_prompt
  end

  def prompt_trail
    return generation_prompt unless editing?
    source_blob = ActiveStorage::Blob.find_by(key: source_blob_key)
    base = source_blob&.metadata&.dig("prompt").presence || show.cover_art_prompt
    [ base, "edit: #{edit_prompt}" ].compact.join(" | ")
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
        prompt: generation_prompt,
        n: 1,
        size: "1024x1024",
        quality: "high"
      }.to_json
    )
  end

  def edit_request
    blob = ActiveStorage::Blob.find_by!(key: source_blob_key)
    boundary = "PhishinCoverArt#{SecureRandom.hex(8)}"
    Typhoeus.post(
      "https://api.openai.com/v1/images/edits",
      headers: {
        "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_TOKEN")}",
        "Content-Type" => "multipart/form-data; boundary=#{boundary}"
      },
      body: edit_request_body(blob, boundary)
    )
  end

  def edit_request_body(blob, boundary)
    fields = {
      "model" => "gpt-image-2",
      "prompt" => edit_prompt,
      "n" => "1",
      "size" => "1024x1024",
      "quality" => "high"
    }
    content_type = blob.content_type.presence || "image/png"
    body = String.new(encoding: Encoding::BINARY)
    fields.each do |name, value|
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
      body << value.to_s.b << "\r\n"
    end
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"image\"; filename=\"#{blob.filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << blob.download << "\r\n"
    body << "--#{boundary}--\r\n"
    body
  end

  def upload_candidate(b64, used_prompt)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(b64)),
      filename: "cover_art_candidate_#{SecureRandom.hex}.png",
      content_type: "image/png",
      metadata: used_prompt.present? ? { "prompt" => used_prompt } : {}
    )
    "#{App.base_url}/blob/#{blob.key}.png"
  end
end
