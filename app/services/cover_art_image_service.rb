class CoverArtImageService < ApplicationService
  param :show
  option :dry_run, default: -> { false }
  option :source_blob_key, default: -> { nil }
  option :edit_prompt, default: -> { nil }
  option :prompt_override, default: -> { nil }

  TEXT_INPUT_RATE = 5.0 / 1_000_000
  IMAGE_INPUT_RATE = 8.0 / 1_000_000
  IMAGE_OUTPUT_RATE = 30.0 / 1_000_000

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
    unless response.success?
      raise "Failed to generate cover art: #{safe_body(response)}"
    end

    result = JSON.parse(safe_body(response))
    url = upload_candidate(result["data"].first["b64_json"], usage_cost(result["usage"]))
    show.attach_cover_art_by_url(url) unless dry_run
    url
  end

  def usage_cost(usage)
    return nil if usage.blank?
    details = usage["input_tokens_details"] || {}
    text_in = details["text_tokens"] || usage["input_tokens"] || 0
    image_in = details["image_tokens"] || 0
    out = usage["output_tokens"] || 0
    (text_in * TEXT_INPUT_RATE + image_in * IMAGE_INPUT_RATE + out * IMAGE_OUTPUT_RATE)
      .round(4)
  end

  def safe_body(response)
    response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def generation_prompt
    prompt_override.presence || show.cover_art_prompt
  end

  def source_metadata
    @source_metadata ||=
      ActiveStorage::Blob.find_by(key: source_blob_key)&.metadata || {}
  end

  def base_prompt
    return generation_prompt unless editing?
    source_metadata["prompt"].presence || show.cover_art_prompt
  end

  def edit_chain
    return [] unless editing?
    Array(source_metadata["edits"]) + [ edit_prompt ]
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

  def upload_candidate(b64, cost)
    metadata = {}
    metadata["prompt"] = base_prompt if base_prompt.present?
    metadata["edits"] = edit_chain if edit_chain.any?
    metadata["cost"] = cost if cost.present?
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(b64)),
      filename: "cover_art_candidate_#{SecureRandom.hex}.png",
      content_type: "image/png",
      metadata:
    )
    "#{App.base_url}/blob/#{blob.key}.png"
  end
end
